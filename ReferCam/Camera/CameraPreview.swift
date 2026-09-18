import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.updateMirroring()
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }
        view.updateMirroring()
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        updateMirroring()
    }

    func updateMirroring() {
        guard let session = previewLayer.session,
              let connection = previewLayer.connection,
              connection.isVideoMirroringSupported else { return }

        let isFront = session.inputs.contains {
            ($0 as? AVCaptureDeviceInput)?.device.position == .front
        }
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirrored != isFront {
            connection.isVideoMirrored = isFront
        }
    }
}
