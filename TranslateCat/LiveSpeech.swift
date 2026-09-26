import AVFoundation
import Foundation
import Speech

/// Live microphone transcription. Does not download speech models.
@MainActor
@Observable
final class LiveSpeech {
    private(set) var isListening = false
    private(set) var isStarting = false
    private(set) var partial = ""
    private(set) var status: String?

    static let unavailable = "Speech recognition isn't available here. Type a line instead."
    static let denied = "Speech recognition is off. Type a line instead."
    static let micOff = "Microphone access is off. Type a line instead."

    private var startGeneration = 0
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var provider: CaptureInputSequenceProvider?
    private var resultsTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var engine: AVAudioEngine?
    private var tapInstalled = false

    func start(locale: Locale, session: AVCaptureSession) async -> Bool {
        if isListening { return true }
        startGeneration += 1
        let generation = startGeneration
        isStarting = true
        status = nil
        defer {
            if generation == startGeneration {
                isStarting = false
            }
        }

        guard await authorizeSpeech() else {
            if generation == startGeneration { status = Self.denied }
            return false
        }
        guard generation == startGeneration else { return false }

        let microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphoneGranted else {
            if generation == startGeneration { status = Self.micOff }
            return false
        }
        guard generation == startGeneration else { return false }

        do {
            try await startAnalyzer(locale: locale, session: session, generation: generation)
            return generation == startGeneration && isListening
        } catch {
            await teardownAnalyzer()
            guard generation == startGeneration else { return false }
            do {
                try startRecognizer(locale: locale)
                return generation == startGeneration && isListening
            } catch {
                teardownRecognizer()
                if generation == startGeneration {
                    status = Self.unavailable
                    isListening = false
                }
                return false
            }
        }
    }

    func stop() async -> String {
        startGeneration += 1
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        isListening = false
        isStarting = false
        await teardownAnalyzer()
        teardownRecognizer()
        partial = ""
        return text
    }

    private func startAnalyzer(locale: Locale, session: AVCaptureSession, generation: Int) async throws {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let modules: [any SpeechModule] = [transcriber]
        let assetStatus = await AssetInventory.status(forModules: modules)
        if assetStatus == .unsupported {
            throw LiveSpeechError.unavailable
        }
        if assetStatus != .installed {
            status = "Preparing on-device speech for \(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)…"
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: modules) else {
                throw LiveSpeechError.unavailable
            }
            try await request.downloadAndInstall()
            guard generation == startGeneration else { throw LiveSpeechError.unavailable }
        }
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw LiveSpeechError.unavailable
        }

        let provider = try await CaptureInputSequenceProvider.provider(
            from: microphone,
            in: session,
            compatibleWith: modules
        )
        guard generation == startGeneration else { throw LiveSpeechError.unavailable }

        let options = SpeechAnalyzer.Options(
            priority: .userInitiated,
            modelRetention: .whileInUse,
            ignoresResourceLimits: true
        )
        let analyzer = SpeechAnalyzer(modules: modules, options: options)
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules)
        try await analyzer.prepareToAnalyze(in: format)
        guard generation == startGeneration else { throw LiveSpeechError.unavailable }

        self.transcriber = transcriber
        self.provider = provider
        self.analyzer = analyzer
        partial = ""
        isListening = true
        status = nil
        observe(transcriber)

        let inputs = provider.analyzerInputs
        analysisTask = Task {
            do {
                try await analyzer.start(inputSequence: inputs)
            } catch {
                await MainActor.run {
                    guard self.isListening else { return }
                    self.status = Self.unavailable
                    self.isListening = false
                }
            }
        }
    }

    private func observe(_ transcriber: SpeechTranscriber) {
        resultsTask = Task { @MainActor [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    self?.partial = text
                }
            } catch {
                guard let self, self.isListening else { return }
                self.status = Self.unavailable
                self.isListening = false
            }
        }
    }

    private func startRecognizer(locale: Locale) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw LiveSpeechError.unavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw LiveSpeechError.unavailable
        }
        recognizer.supportsOnDeviceRecognition = true

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw LiveSpeechError.unavailable
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true
        self.request = request
        self.engine = engine
        self.recognizer = recognizer
        partial = ""
        isListening = true
        status = nil

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            DispatchQueue.main.async {
                guard let self else { return }
                if let text {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        self.partial = trimmed
                    }
                }
                if error != nil, self.partial.isEmpty, self.isListening {
                    self.status = Self.unavailable
                    self.isListening = false
                    self.teardownRecognizer()
                }
            }
        }

        engine.prepare()
        try engine.start()
    }

    private func teardownAnalyzer() async {
        resultsTask?.cancel()
        resultsTask = nil
        analysisTask?.cancel()
        analysisTask = nil
        let analyzer = self.analyzer
        provider = nil
        self.analyzer = nil
        transcriber = nil
        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }
    }

    private func teardownRecognizer() {
        recognitionTask?.cancel()
        recognitionTask = nil
        request?.endAudio()
        request = nil
        recognizer = nil
        if let engine {
            engine.stop()
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
            }
        }
        engine = nil
        tapInstalled = false
    }

    private func authorizeSpeech() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }
}

private enum LiveSpeechError: Error {
    case unavailable
}
