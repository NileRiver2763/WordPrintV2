import Foundation
import AVFoundation
import Speech

// Result of the permission-request sequence.
enum SRPermission {
    case granted
    case microphoneDenied
    case speechDenied
    case notAvailable
}

// Errors thrown by startRecording().
enum SRError: LocalizedError {
    case recognizerUnavailable
    case audioEngineFailure(Error)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device right now."
        case .audioEngineFailure(let e):
            return "Could not start the microphone: \(e.localizedDescription)"
        }
    }
}

// ─────────────────────────────────────────────────────────────
// SpeechRecognizer
//
// How the two frameworks fit together:
//
//  AVAudioEngine        ──tap──►  SFSpeechAudioBufferRecognitionRequest
//    (captures PCM                 (streams raw audio into the recognizer)
//     from mic)
//                                         │
//                               SFSpeechRecognizer
//                                 .recognitionTask(with:)
//                                         │
//                               SFSpeechRecognitionResult
//                                 .bestTranscription.formattedString
//                                    (live text update)
// ─────────────────────────────────────────────────────────────
final class SpeechRecognizer: ObservableObject {

    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?

    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Accumulates text from segments that the recognizer has finalized (isFinal).
    // Each pause causes iOS to commit a segment; we append rather than overwrite.
    private var committedText: String = ""

    // Latest uncommitted hypothesis, and a counter that invalidates stale task callbacks.
    private var lastPartial: String = ""
    private var taskGeneration: Int = 0
    private var consecutiveFailures = 0

    // AVAudioEngine owns the audio graph; inputNode is its microphone tap point.
    private let audioEngine = AVAudioEngine()

    // Stopping the engine and deactivating the audio session can block for a long time,
    // so all engine/session work runs here, never on the main thread while the UI waits.
    private let audioQueue = DispatchQueue(label: "wordprint.audio")

    // Pause detection runs on the audio thread, so it is guarded by a lock.
    private let pauseLock = NSLock()
    private var pauseDetector = PauseDetector()

    /// Pauses heard so far in this recording.
    var pauseStats: PauseStats {
        pauseLock.lock(); defer { pauseLock.unlock() }
        return pauseDetector.stats
    }

    init() {
        // Locale.current picks the user's device language automatically.
        recognizer = SFSpeechRecognizer(locale: .current)
    }

    deinit {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Permissions

    /// Ask for both permissions in sequence. Returns the first denial found.
    func requestPermissions() async -> SRPermission {
        guard let recognizer, recognizer.isAvailable else {
            return .notAvailable
        }

        // iOS 17+ async microphone permission API.
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { return .microphoneDenied }

        // Speech recognition still uses a callback-based API; wrap in a continuation.
        let speechStatus: SFSpeechRecognizerAuthorizationStatus =
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        guard speechStatus == .authorized else { return .speechDenied }

        return .granted
    }

    // MARK: - Recording

    /// Wire AVAudioEngine → SFSpeechRecognizer and start streaming audio.
    func startRecording() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw SRError.recognizerUnavailable
        }

        // Tear down any previous session first.
        stopRecording()
        transcript = ""
        committedText = ""
        lastPartial = ""
        errorMessage = nil
        consecutiveFailures = 0
        pauseLock.lock(); pauseDetector = PauseDetector(); pauseLock.unlock()

        // Steps 1–3 run on the audio queue, which also waits for any earlier teardown.
        //   Session: .record + .measurement (no echo cancel / AGC), duckOthers.
        //   Tap: routes audio through self?.recognitionRequest so the request can be swapped
        //   after a pause without restarting the engine.
        try audioQueue.sync {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
                self?.measureLevel(of: buffer)
            }

            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                // Remove the tap, otherwise the next attempt crashes installing a second one.
                inputNode.removeTap(onBus: 0)
                throw SRError.audioEngineFailure(error)
            }
        }

        // Step 4 — Start the first recognition task. Subsequent segments after
        //   pauses are handled inside beginRecognitionTask() automatically.
        beginRecognitionTask()

        isRecording = true
    }

    // Loudness of one buffer (RMS in dBFS) → pause detector. Runs on the audio thread.
    private func measureLevel(of buffer: AVAudioPCMBuffer) {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0, buffer.format.sampleRate > 0 else { return }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += samples[i] * samples[i] }
        let rms = (sum / Float(n)).squareRoot()
        let db = 20 * log10(Double(max(rms, 1e-5)))
        let seconds = Double(n) / buffer.format.sampleRate
        pauseLock.lock()
        pauseDetector.add(levelDB: db, duration: seconds)
        pauseLock.unlock()
    }

    // Creates a fresh SFSpeechAudioBufferRecognitionRequest and recognition task.
    // Called at start and again each time iOS commits a finalized segment.
    // The audio tap stays live throughout — only the request object is swapped.
    private func beginRecognitionTask() {
        guard let recognizer, recognizer.isAvailable else { return }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        lastPartial = ""
        let generation = taskGeneration &+ 1
        taskGeneration = generation

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                // Ignore callbacks from tasks we've already replaced or cancelled.
                guard let self, self.taskGeneration == generation, self.isRecording else { return }

                if let result {
                    let live = result.bestTranscription.formattedString
                    if !live.isEmpty { self.consecutiveFailures = 0 }

                    if result.isFinal {
                        self.commit(live.isEmpty ? self.lastPartial : live)
                        self.restartTask()
                        return
                    }

                    // After a pause the recognizer can silently start a new
                    // utterance without isFinal: the text shrinks or no longer
                    // extends the previous hypothesis. Commit the old one first
                    // so it isn't overwritten.
                    if !self.lastPartial.isEmpty, !live.isEmpty, !self.extends(live, self.lastPartial) {
                        self.commit(self.lastPartial)
                    }
                    self.lastPartial = live
                    self.transcript = self.committedText.isEmpty
                        ? live
                        : (live.isEmpty ? self.committedText : self.committedText + " " + live)
                }

                if let error {
                    // 1110 = no speech detected (normal during silence);
                    // 203/301 = task cancelled.
                    let code = (error as NSError).code
                    // The task ended (timeout or silence). Keep what we heard.
                    self.commit(self.lastPartial)
                    self.transcript = self.committedText

                    let benign = code == 1110 || code == 203 || code == 301
                    if !benign {
                        self.consecutiveFailures += 1
                        self.errorMessage = error.localizedDescription
                        // Don't spin forever if the recognizer keeps failing.
                        if self.consecutiveFailures > 5 { return }
                    }
                    // Brief delay so a failing recognizer can't restart in a tight loop.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        guard let self, self.isRecording, self.taskGeneration == generation else { return }
                        self.restartTask()
                    }
                }
            }
        }
    }

    // Appends a finished segment to the accumulated transcript.
    private func commit(_ segment: String) {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        committedText = committedText.isEmpty ? trimmed : committedText + " " + trimmed
        lastPartial = ""
        transcript = committedText
    }

    private func restartTask() {
        recognitionRequest = nil
        beginRecognitionTask()
    }

    // True if `new` is a continuation (possibly with corrections) of `old`
    // rather than a fresh utterance.
    private func extends(_ new: String, _ old: String) -> Bool {
        let n = new.lowercased(), o = old.lowercased()
        if n.hasPrefix(o) || o.hasPrefix(n) && n.count + 3 >= o.count { return true }
        // Allow small revisions: compare the first few words.
        let nw = n.split(separator: " ").prefix(2), ow = o.split(separator: " ").prefix(2)
        return !nw.isEmpty && nw.elementsEqual(ow)
    }

    /// Wipes everything the user has said so far and starts listening fresh.
    func clearTranscript() {
        committedText = ""
        lastPartial = ""
        transcript = ""
        if isRecording {
            recognitionRequest = nil
            beginRecognitionTask()
        }
    }

    /// Signal end-of-audio, drain remaining results, tear down the engine.
    func stopRecording() {
        guard isRecording else { return }

        // Telling the request endAudio() lets the recognizer flush its final hypothesis.
        recognitionRequest?.endAudio()

        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        let engine = audioEngine
        audioQueue.async {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance()
                .setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
