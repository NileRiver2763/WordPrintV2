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

    // AVAudioEngine owns the audio graph; inputNode is its microphone tap point.
    private let audioEngine = AVAudioEngine()

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

        // Step 1 — Configure the audio session.
        //   .record      = mic-only, no playback mixing
        //   .measurement = no system audio processing (echo cancel, AGC) applied,
        //                  giving the cleanest signal for speech recognition
        //   .duckOthers  = temporarily lower background audio while we record
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Step 2 — Tap the microphone.
        //   The tap routes audio through self?.recognitionRequest so we can swap
        //   the request when iOS finalizes a segment after a pause, without
        //   stopping or restarting the audio engine.
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Step 3 — Start the audio engine.
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SRError.audioEngineFailure(error)
        }

        // Step 4 — Start the first recognition task. Subsequent segments after
        //   pauses are handled inside beginRecognitionTask() automatically.
        beginRecognitionTask()

        isRecording = true
    }

    // Creates a fresh SFSpeechAudioBufferRecognitionRequest and recognition task.
    // Called at start and again each time iOS commits a finalized segment.
    // The audio tap stays live throughout — only the request object is swapped.
    private func beginRecognitionTask() {
        guard let recognizer, recognizer.isAvailable else { return }

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
                    // 1110 = no speech detected; 203/301 = task cancelled by us.
                    let code = (error as NSError).code
                    // The task ended (timeout or silence). Keep what we heard
                    // and keep listening.
                    self.commit(self.lastPartial)
                    self.transcript = self.committedText
                    if code != 1110 && code != 203 && code != 301 {
                        self.errorMessage = error.localizedDescription
                    }
                    self.restartTask()
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

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}
