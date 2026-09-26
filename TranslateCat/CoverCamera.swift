import AVFoundation
import Observation

@MainActor
@Observable
final class CoverCamera {
    let session = AVCaptureSession()
    private(set) var isRunning = false
    private(set) var status: String?
    private var started = false

    func start() async {
        guard !started else { return }
        started = true

        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            granted = false
        }

        guard granted else {
            status = "Camera access is off. The cover screen stays on this display."
            return
        }

        do {
            try configure()
        } catch {
            status = status ?? "The camera could not start. The cover screen stays on this display."
            return
        }

        let running = await startRunning()
        isRunning = running
        if !running {
            status = "The camera could not start. The cover screen stays on this display."
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            status = "No camera on this device. The cover screen stays on this display."
            throw CameraSetupError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            status = "The camera could not start. The cover screen stays on this display."
            throw CameraSetupError.unavailable
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    private func startRunning() async -> Bool {
        let session = self.session
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume(returning: session.isRunning)
            }
        }
    }
}

private enum CameraSetupError: Error {
    case unavailable
}
