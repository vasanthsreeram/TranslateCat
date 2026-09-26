import AVFoundation
import Foundation
import Observation

/// Keeps the microphone open and hands over each spoken utterance, split on pauses, as 16 kHz WAV.
@MainActor
@Observable
final class AutoListener {
    private(set) var isRunning = false
    private(set) var isHearingSpeech = false

    @ObservationIgnored var onUtterance: ((Data) -> Void)?

    private var engine: AVAudioEngine?
    private var samples: [Int16] = []
    private var speechDuration: TimeInterval = 0
    private var silenceDuration: TimeInterval = 0
    private var noiseFloor: Float = 0.01

    private static let sampleRate = 16_000.0
    private static let pauseToFinish: TimeInterval = 0.8
    private static let minimumSpeech: TimeInterval = 0.35
    private static let maximumUtterance: TimeInterval = 15

    func start() async throws {
        guard !isRunning else { return }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw ListenerError.microphoneOff
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Self.sampleRate,
                                               channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw ListenerError.unavailable
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let chunk = Self.convert(buffer, with: converter, to: outputFormat) else { return }
            Task { @MainActor in self?.process(chunk) }
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
        resetUtterance()
        isRunning = true
    }

    func stop() {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        isRunning = false
        resetUtterance()
    }

    private func process(_ chunk: [Int16]) {
        guard isRunning, !chunk.isEmpty else { return }
        let duration = Double(chunk.count) / Self.sampleRate
        let level = Self.rms(chunk)
        let threshold = max(0.02, noiseFloor * 3)
        let loud = level > threshold

        if loud {
            if !isHearingSpeech {
                isHearingSpeech = true
            }
            speechDuration += duration
            silenceDuration = 0
            samples.append(contentsOf: chunk)
        } else if isHearingSpeech {
            silenceDuration += duration
            samples.append(contentsOf: chunk)
        } else {
            noiseFloor = noiseFloor * 0.9 + level * 0.1
            // Keep a short lead-in so the first syllable isn't clipped.
            samples.append(contentsOf: chunk)
            let leadIn = Int(Self.sampleRate * 0.3)
            if samples.count > leadIn {
                samples.removeFirst(samples.count - leadIn)
            }
            return
        }

        let total = Double(samples.count) / Self.sampleRate
        if silenceDuration >= Self.pauseToFinish || total >= Self.maximumUtterance {
            if speechDuration >= Self.minimumSpeech {
                onUtterance?(Self.wav(from: samples))
            }
            resetUtterance()
        }
    }

    private func resetUtterance() {
        samples.removeAll(keepingCapacity: true)
        speechDuration = 0
        silenceDuration = 0
        isHearingSpeech = false
    }

    nonisolated private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                            to format: AVAudioFormat) -> [Int16]? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let data = output.int16ChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(output.frameLength)))
    }

    private static func rms(_ chunk: [Int16]) -> Float {
        var sum: Float = 0
        for sample in chunk {
            let value = Float(sample) / Float(Int16.max)
            sum += value * value
        }
        return (sum / Float(chunk.count)).squareRoot()
    }

    private static func wav(from samples: [Int16]) -> Data {
        let dataSize = UInt32(samples.count * 2)
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36) + dataSize)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}

enum ListenerError: LocalizedError {
    case microphoneOff
    case unavailable

    var errorDescription: String? {
        switch self {
        case .microphoneOff: "Microphone access is off. Turn it on in Settings to translate speech."
        case .unavailable: "The microphone isn’t available right now."
        }
    }
}
