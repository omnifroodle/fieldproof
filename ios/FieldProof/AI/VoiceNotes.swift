import AVFoundation
import Foundation
import Speech

/// Dictated notes, transcribed on the phone. Talking point: `requiresOnDeviceRecognition` keeps the audio
/// and the transcription on the device, so a crew member can dictate in a canyon with no signal.
@MainActor
final class VoiceNotes: ObservableObject {

    // MARK: - Published

    @Published private(set) var isRecording = false
    @Published private(set) var heard = ""
    /// Shown under the button when the phone cannot do this: no permission, no on-device model, no microphone.
    @Published private(set) var trouble: String?

    // MARK: - Private

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // MARK: - Start and stop

    func toggle() { isRecording ? stop() : start() }

    private func start() {
        heard = ""
        trouble = nil
        SFSpeechRecognizer.requestAuthorization { speech in
            AVAudioApplication.requestRecordPermission { microphone in
                Task { @MainActor in
                    guard speech == .authorized else { self.trouble = "Speech recognition was not allowed"; return }
                    guard microphone else { self.trouble = "The microphone was not allowed"; return }
                    self.listen()
                }
            }
        }
    }

    private func listen() {
        guard let recognizer, recognizer.isAvailable else { trouble = "No recognizer for this language"; return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Talking point: this is the line that keeps the recording off the network.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        if !recognizer.supportsOnDeviceRecognition { trouble = "This language has no on-device model; not recording" ; return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
        } catch {
            trouble = "The microphone could not start"
            return
        }

        self.request = request
        isRecording = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.heard = result.bestTranscription.formattedString }
                if let error {
                    // The simulator has no microphone input, so this is where it lands. A device transcribes.
                    self.trouble = "Dictation stopped: \(error.localizedDescription)"
                    self.stop()
                } else if result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isRecording || engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
