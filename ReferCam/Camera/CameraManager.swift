import AVFoundation
import Combine
import UIKit

final class CameraManager: ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "ReferCam.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var photoDelegate: PhotoCaptureDelegate?

    @MainActor
    func requestAccess() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }

        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus != .authorized {
            errorMessage = "Camera access is required. Enable it in Settings."
            return false
        }

        errorMessage = nil
        return true
    }

    func startSession() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            publishError("Camera access is required. Enable it in Settings.")
            return
        }

        sessionQueue.async { [weak self] in
            guard let self, self.configureSessionIfNeeded() else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning, self.isConfigured else {
                self.publishError("Camera is not ready yet.")
                return
            }
            guard self.photoDelegate == nil else { return }

            let settings = AVCapturePhotoSettings()
            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            let delegate = PhotoCaptureDelegate { [weak self] result in
                guard let self else { return }
                self.sessionQueue.async {
                    self.photoDelegate = nil
                }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let image):
                        self.capturedImage = image
                        self.errorMessage = nil
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            self.photoDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self, self.configureSessionIfNeeded(), let currentInput = self.videoInput else { return }
            guard self.photoDelegate == nil else { return }
            let position: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                self.publishError("The requested camera is unavailable.")
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                self.session.removeInput(currentInput)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoInput = newInput
                    self.publishError(nil)
                } else {
                    self.session.addInput(currentInput)
                    self.publishError("Could not switch cameras.")
                }
                self.session.commitConfiguration()
            } catch {
                self.publishError(error.localizedDescription)
            }
        }
    }

    private func configureSessionIfNeeded() -> Bool {
        if isConfigured { return true }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            publishError("No rear camera is available on this device.")
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.sessionPreset = .photo
            guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                publishError("Could not configure the camera.")
                return false
            }
            session.addInput(input)
            session.addOutput(photoOutput)
            session.commitConfiguration()
            videoInput = input
            isConfigured = true
            publishError(nil)
            return true
        } catch {
            publishError(error.localizedDescription)
            return false
        }
    }

    private func publishError(_ message: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, Error>) -> Void
    private var result: Result<UIImage, Error>?

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(CameraCaptureError.imageUnavailable)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error {
            completion(.failure(error))
        } else {
            completion(result ?? .failure(CameraCaptureError.imageUnavailable))
        }
    }
}

private enum CameraCaptureError: LocalizedError {
    case imageUnavailable

    var errorDescription: String? {
        "Could not process the captured photo."
    }
}
