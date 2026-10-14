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
        errorMessage = nil

        // Step 1 — Configure the audio session.
        //   .record      = mic-only, no playback mixing
        //   .measurement = no system audio processing (echo cancel, AGC) applied,
        //                  giving the cleanest signal for speech recognition
        //   .duckOthers  = temporarily lower background audio while we record
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Step 2 — Create the recognition request.
        //   SFSpeechAudioBufferRecognitionRequest is the streaming variant;
        //   we feed it raw PCM buffers in real time (vs. a finished audio file).
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true   // live text updates as user speaks
        request.requiresOnDeviceRecognition = true  // never leave the device
        recognitionRequest = request

        // Step 3 — Tap the microphone.
        //   inputNode is AVAudioEngine's live microphone source.
        //   We install a "tap" that fires every ~23 ms (at 1024 samples, 44 kHz).
        //   Each buffer is handed straight to the recognition request.
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Capture `request` directly — avoids touching self from the audio thread.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        // Step 4 — Start the audio engine.
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SRError.audioEngineFailure(error)
        }

        // Step 5 — Start the recognition task.
        //   The closure is called whenever Apple's on-device model produces
        //   a new hypothesis (partial) or a final result.
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result {
                    // bestTranscription is the highest-confidence hypothesis so far.
                    self?.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    // Code 1110 = "no speech detected" — normal during silence, not a fault.
                    // Code 203 / 301 = task cancelled by us — also not a fault.
                    let code = (error as NSError).code
                    if code != 1110 && code != 203 && code != 301 {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        isRecording = true
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
