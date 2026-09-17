import SwiftUI
import UIKit

struct CameraView: View {
    @StateObject private var camera = CameraManager()

    @State private var selectedReference: ReferencePhoto?
    @State private var referenceOpacity: Double = 0.55

    @State private var reviewImage: UIImage?
    @State private var saveStatus: SaveStatus?
    @State private var isSaving = false

    @State private var visibleErrorMessage: String?
    @State private var errorDismissed = false

    private enum SaveStatus: Equatable {
        case success
        case failure(String)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.authorizationStatus == .authorized {
                liveCameraLayer
            } else {
                permissionGate
            }

            if let reviewImage {
                reviewLayer(reviewImage)
                    .transition(.opacity)
            }

            errorBanner
        }
        .statusBarHidden(true)
        .task {
            if await camera.requestAccess() {
                camera.startSession()
            }
        }
        .onDisappear {
            camera.stopSession()
        }
        .onReceive(camera.$capturedImage) { image in
            guard let image else { return }
            saveStatus = nil
            reviewImage = image
        }
        .onReceive(camera.$errorMessage) { message in
            guard let message, !message.isEmpty else { return }
            visibleErrorMessage = message
            errorDismissed = false
        }
    }

    // MARK: - Live camera

    private var liveCameraLayer: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            if let selectedReference {
                referenceOverlay(selectedReference)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                bottomControls
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.35), in: Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func referenceOverlay(_ reference: ReferencePhoto) -> some View {
        if reference.isAssetAvailable {
            Image(reference.assetName)
                .resizable()
                .scaledToFit()
                .opacity(referenceOpacity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 40))
                Text("\"\(reference.assetName)\" image missing")
                    .font(.caption)
            }
            .padding(20)
            .foregroundStyle(.white.opacity(min(referenceOpacity + 0.3, 1)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(.white.opacity(min(referenceOpacity + 0.3, 1)))
            )
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if selectedReference != nil {
                opacitySlider
            }
            referenceStrip
            shutterRow
        }
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var opacitySlider: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(.white.opacity(0.8))
            Slider(value: $referenceOpacity, in: 0.1...1)
            Text("\(Int(referenceOpacity * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal)
    }

    private var referenceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                referenceThumbnail(nil, label: "None", systemImage: "nosign")

                ForEach(ReferencePhoto.samples) { reference in
                    referenceThumbnail(reference, label: reference.title, systemImage: "photo")
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func referenceThumbnail(_ reference: ReferencePhoto?, label: String, systemImage: String) -> some View {
        let isSelected = selectedReference == reference

        Button {
            selectedReference = reference
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.15))

                    if let reference, reference.isAssetAvailable {
                        Image(reference.assetName)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: systemImage)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.yellow : .clear, lineWidth: 2)
                )

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var shutterRow: some View {
        HStack {
            Spacer()
            Button {
                camera.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 74, height: 74)
                    Circle()
                        .fill(.white)
                        .frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Permission gate

    private var permissionGate: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.8))

            switch camera.authorizationStatus {
            case .denied, .restricted:
                Text("Camera access is off")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Enable camera access in Settings to use ReferCam.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            default:
                Text("Requesting camera access…")
                    .font(.headline)
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white)
            }
        }
        .padding(32)
    }

    // MARK: - Review / save

    @ViewBuilder
    private func reviewLayer(_ image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            if let saveStatus {
                VStack {
                    saveStatusBanner(saveStatus)
                        .padding(.top, 12)
                    Spacer()
                }
            }

            VStack {
                Spacer()
                reviewControls(image)
            }
        }
    }

    private func reviewControls(_ image: UIImage) -> some View {
        HStack(spacing: 40) {
            reviewButton(title: "Retake", systemImage: "arrow.counterclockwise") {
                reviewImage = nil
                saveStatus = nil
            }

            reviewButton(
                title: isSaving ? "Saving…" : "Save",
                systemImage: "square.and.arrow.down",
                isProminent: true,
                isDisabled: isSaving
            ) {
                Task { await save(image) }
            }
        }
        .padding(.bottom, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func reviewButton(
        title: String,
        systemImage: String,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if isDisabled {
                    ProgressView()
                        .tint(.white)
                        .frame(height: 26)
                } else {
                    Image(systemName: systemImage)
                        .font(.title2)
                }
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 88, height: 64)
            .background(
                isProminent ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(isDisabled)
    }

    private func saveStatusBanner(_ status: SaveStatus) -> some View {
        Group {
            switch status {
            case .success:
                Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.75), in: Capsule())
        .foregroundStyle(.white)
    }

    private func save(_ image: UIImage) async {
        isSaving = true
        saveStatus = nil
        do {
            try await ImageService.saveToPhotos(ImageService.outputImage(from: image))
            saveStatus = .success
        } catch {
            saveStatus = .failure(error.localizedDescription)
        }
        isSaving = false

        if saveStatus == .success {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if saveStatus == .success {
                reviewImage = nil
                saveStatus = nil
            }
        }
    }

    // MARK: - Error banner

    @ViewBuilder
    private var errorBanner: some View {
        if let visibleErrorMessage, !errorDismissed, reviewImage == nil {
            VStack {
                HStack {
                    Text(visibleErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        errorDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(12)
                .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }
        }
    }
}
