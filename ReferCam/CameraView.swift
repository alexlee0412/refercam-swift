import PhotosUI
import SwiftUI
import UIKit

// MARK: - Stage palette (viewfinder stays dark regardless of the Display theme setting;
// these values are ported as hardcoded literals directly from the prototype's CSS, which
// never routes the stage's own colors through its themed --bg/--fg custom properties)

private enum StagePalette {
    static let stageBg = Color(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x1a / 255.0)
    static let hintBg = Color(red: 0x0c / 255.0, green: 0x0c / 255.0, blue: 0x0d / 255.0).opacity(0.6)
    static let capsuleBg = Color(red: 0x0c / 255.0, green: 0x0c / 255.0, blue: 0x0d / 255.0).opacity(0.45)
    static let refChipBorder = Color.white.opacity(0.28)
    static let fg = Color(red: 0xf2 / 255.0, green: 0xf2 / 255.0, blue: 0xf0 / 255.0)
    static let chipFg = Color(red: 0xb7 / 255.0, green: 0xb7 / 255.0, blue: 0xb0 / 255.0)
}

// MARK: - Wordmark ("bead" letters, ported from .bead in the prototype)

private struct Bead {
    let letter: String
    let tilt: Double
}

private let wordmarkBeads: [Bead] = [
    Bead(letter: "R", tilt: -3), Bead(letter: "E", tilt: 2), Bead(letter: "F", tilt: -2),
    Bead(letter: "E", tilt: 3), Bead(letter: "R", tilt: -1),
    Bead(letter: "C", tilt: 2), Bead(letter: "A", tilt: -3), Bead(letter: "M", tilt: 1)
]

// MARK: - Control option types (ported from the prototype's chip rows)

private enum ShootMode: String, CaseIterable, Identifiable {
    case instant, burst
    var id: String { rawValue }
    var l10nKey: String { self == .instant ? "mode.instant" : "mode.burst" }
}

private enum CaptureType: String, CaseIterable, Identifiable {
    case photo, video
    var id: String { rawValue }
    var l10nKey: String { self == .photo ? "chip.photo" : "chip.video" }
}

private struct CaptureRatio: Identifiable, Equatable {
    let id: String
    let w: CGFloat
    let h: CGFloat
    let iconSize: CGSize
    var value: CGFloat { w / h }

    static let all: [CaptureRatio] = [
        CaptureRatio(id: "3:4", w: 3, h: 4, iconSize: CGSize(width: 13.5, height: 18)),
        CaptureRatio(id: "4:3", w: 4, h: 3, iconSize: CGSize(width: 18, height: 13.5)),
        CaptureRatio(id: "1:1", w: 1, h: 1, iconSize: CGSize(width: 18, height: 18)),
        CaptureRatio(id: "4:5", w: 4, h: 5, iconSize: CGSize(width: 14.4, height: 18)),
        CaptureRatio(id: "5:4", w: 5, h: 4, iconSize: CGSize(width: 18, height: 14.4)),
        CaptureRatio(id: "9:16", w: 9, h: 16, iconSize: CGSize(width: 10.1, height: 18))
    ]
}

private enum TimerOption: Int, CaseIterable, Identifiable {
    case off = 0, three = 3, five = 5, ten = 10
    var id: Int { rawValue }
    var l10nKey: String {
        switch self {
        case .off: return "timer.off"
        case .three: return "timer.3"
        case .five: return "timer.5"
        case .ten: return "timer.10"
        }
    }
}

// MARK: - CameraView

struct CameraView: View {
    @StateObject private var camera = CameraManager()

    @AppStorage(AppStorageKey.saveAsPreviewed) private var saveAsPreviewed: Bool = true
    @AppStorage(AppStorageKey.silentShutterPreferred) private var silentShutterPreferred: Bool = true
    @AppStorage(AppStorageKey.theme) private var themeRaw: String = AppTheme.dark.rawValue
    @AppStorage(AppStorageKey.language) private var languageRaw: String = AppLanguage.systemDefault().rawValue

    @State private var shootMode: ShootMode = .instant
    @State private var captureType: CaptureType = .photo
    @State private var captureRatio = CaptureRatio.all[0]
    @State private var timerOption: TimerOption = .off
    @State private var countdownValue: Int?

    @State private var selectedReference: ReferencePhoto?
    @State private var referenceOpacity: Double = 0.55
    @State private var showReferencePicker = false
    @State private var showSettings = false

    @State private var showScenePicker = false
    @State private var pickedSceneItem: PhotosPickerItem?
    @State private var simulatedScene: UIImage?

    @State private var reviewImage: UIImage?
    @State private var saveStatus: SaveStatus?
    @State private var isSaving = false

    @State private var visibleErrorMessage: String?

    private enum SaveStatus: Equatable {
        case success
        case failure(String)
    }

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .dark }
    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }
    private var colors: ChromeColors { ChromeColors.resolved(for: theme) }

    /// "iOS 18+ AND device support" -- CameraManager reports device/session support via
    /// isShutterSoundSuppressionSupported, but the OS-version half of the gate belongs here.
    private var isSilentShutterAvailable: Bool {
        if #available(iOS 18.0, *) {
            return camera.isShutterSoundSuppressionSupported
        }
        return false
    }

    private func t(_ key: String) -> String { L10n.t(key, language) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            stageArea
            controlChips
            bottomBar
        }
        .background(colors.bg.ignoresSafeArea())
        .statusBarHidden(true)
        .preferredColorScheme(theme.colorScheme)
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
            visibleErrorMessage = (message?.isEmpty == false) ? message : nil
        }
        .photosPicker(isPresented: $showScenePicker, selection: $pickedSceneItem, matching: .images)
        .onChange(of: pickedSceneItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    simulatedScene = image
                }
            }
        }
        // Settings is presented as a plain .sheet, which does not remove CameraView from
        // the hierarchy, so it never triggers .onDisappear above -- the capture session
        // (owned entirely by CameraManager) keeps running under the sheet.
        .sheet(isPresented: $showSettings) {
            SettingsView(isSilentShutterSupported: isSilentShutterAvailable)
        }
        .sheet(isPresented: $showReferencePicker) {
            referencePickerSheet
        }
        .sheet(isPresented: Binding(
            get: { reviewImage != nil },
            set: { isPresented in
                if !isPresented {
                    reviewImage = nil
                    saveStatus = nil
                }
            }
        )) {
            if let reviewImage {
                resultSheet(reviewImage)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            wordmark
            Spacer(minLength: 8)
            modeSegment
            miniButton(systemImage: "gearshape", accessibilityLabel: t("a11y.settings")) {
                showSettings = true
            }
            miniButton(systemImage: "arrow.triangle.2.circlepath.camera", accessibilityLabel: t("a11y.switchCam")) {
                camera.switchCamera()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var wordmark: some View {
        HStack(spacing: 2) {
            ForEach(Array(wordmarkBeads.enumerated()), id: \.offset) { index, bead in
                Text(bead.letter)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(width: 19, height: 19)
                    .background(
                        Color(red: 0xf7 / 255.0, green: 0xf7 / 255.0, blue: 0xf4 / 255.0),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme == .light ? Color.black.opacity(0.14) : Color.clear, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(bead.tilt))
                if index == 4 {
                    Spacer().frame(width: 5)
                }
            }
        }
        .accessibilityLabel("REFER CAM")
    }

    private var modeSegment: some View {
        HStack(spacing: 2) {
            ForEach(ShootMode.allCases) { mode in
                segButton(title: t(mode.l10nKey), isOn: shootMode == mode, isEnabled: mode == .instant) {
                    shootMode = mode
                }
            }
        }
        .padding(2)
        .background(colors.seg, in: Capsule())
    }

    private func segButton(title: String, isOn: Bool, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .fixedSize()
                .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? colors.invFg : colors.mut)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isOn ? colors.invBg : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityHint(isEnabled ? "" : t("unavailable.hint"))
    }

    private func miniButton(
        systemImage: String,
        accessibilityLabel: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(colors.fg)
                .frame(width: 20, height: 20)
        }
        .padding(9)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.line, lineWidth: 1))
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isEnabled ? "" : t("unavailable.hint"))
    }

    // MARK: - Stage (bounded 3:4-ish camera preview, not edge-to-edge; always dark)

    private var stageArea: some View {
        ZStack {
            stageBaseLayer

            if let selectedReference {
                referenceOverlayLayer(selectedReference)
                    .allowsHitTesting(false)
            }

            if let countdownValue {
                Text("\(countdownValue)")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }

            stageHintOverlay

            if let selectedReference {
                refChipOverlay(selectedReference)
            }

            if selectedReference != nil {
                VStack {
                    Spacer()
                    opacityCapsule
                        .padding(.bottom, 12)
                }
            }
        }
        .aspectRatio(captureRatio.value, contentMode: .fit)
        .background(StagePalette.stageBg)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { handleStageTap() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var stageBaseLayer: some View {
        if let simulatedScene {
            Image(uiImage: simulatedScene)
                .resizable()
                .scaledToFill()
        } else if camera.authorizationStatus == .authorized {
            CameraPreview(session: camera.session)
        } else {
            Color.clear
        }
    }

    private var stageHintText: String? {
        if simulatedScene != nil { return nil }
        switch camera.authorizationStatus {
        case .denied, .restricted:
            return t("cam.denied")
        case .authorized:
            if visibleErrorMessage != nil {
                return t("cam.fail")
            }
            guard selectedReference == nil else { return nil }
            let isSilentActive = silentShutterPreferred && isSilentShutterAvailable
            return t(isSilentActive ? "stage.hint.silent" : "stage.hint.plain")
        default:
            return nil
        }
    }

    @ViewBuilder
    private var stageHintOverlay: some View {
        if let stageHintText {
            VStack {
                Text(stageHintText)
                    .font(.system(size: 11))
                    .foregroundStyle(StagePalette.chipFg)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(StagePalette.hintBg, in: Capsule())
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                Spacer()
            }
        }
    }

    private func handleStageTap() {
        switch camera.authorizationStatus {
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .authorized:
            if visibleErrorMessage != nil, simulatedScene == nil {
                showScenePicker = true
            }
        default:
            break
        }
    }

    private func refChipOverlay(_ reference: ReferencePhoto) -> some View {
        VStack {
            HStack {
                Button {
                    showReferencePicker = true
                } label: {
                    referenceThumbnailImage(reference, fallbackColor: StagePalette.chipFg)
                        .frame(width: 46, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(StagePalette.refChipBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("a11y.currentRef"))
                .padding(.leading, 12)
                .padding(.top, 44)

                Spacer()
            }
            Spacer()
        }
    }

    private var opacityCapsule: some View {
        HStack(spacing: 12) {
            Text(t("row.opacity"))
                .font(.system(size: 12))
                .foregroundStyle(StagePalette.chipFg)
            Slider(value: $referenceOpacity, in: 0...1)
                .tint(accentTint)
            Text("\(Int(referenceOpacity * 100))%")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(StagePalette.fg)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(StagePalette.capsuleBg, in: Capsule())
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func referenceOverlayLayer(_ reference: ReferencePhoto) -> some View {
        if reference.isAssetAvailable {
            Image(reference.assetName)
                .resizable()
                .scaledToFit()
                .opacity(referenceOpacity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 32))
                Text("\"\(reference.assetName)\" image missing")
                    .font(.caption)
            }
            .foregroundStyle(StagePalette.fg.opacity(min(referenceOpacity + 0.3, 1)))
        }
    }

    @ViewBuilder
    private func referenceThumbnailImage(_ reference: ReferencePhoto, fallbackColor: Color) -> some View {
        if reference.isAssetAvailable {
            Image(reference.assetName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(red: 0x22 / 255.0, green: 0x22 / 255.0, blue: 0x22 / 255.0)
                Image(systemName: "photo")
                    .foregroundStyle(fallbackColor)
            }
        }
    }

    // MARK: - Control chip rows (Shoot / Ratio / Timer)

    private var controlChips: some View {
        VStack(alignment: .leading, spacing: 4) {
            chipRow(label: t("row.shoot")) {
                ForEach(CaptureType.allCases) { type in
                    chip(t(type.l10nKey), isOn: captureType == type, isEnabled: type == .photo) {
                        captureType = type
                    }
                }
            }
            chipRow(label: t("row.ratio")) {
                ForEach(CaptureRatio.all) { ratio in
                    ratioChip(ratio, isOn: captureRatio == ratio) {
                        withAnimation(.easeInOut(duration: 0.2)) { captureRatio = ratio }
                    }
                }
            }
            chipRow(label: t("row.timer")) {
                ForEach(TimerOption.allCases) { option in
                    chip(t(option.l10nKey), isOn: timerOption == option) { timerOption = option }
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func chipRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(colors.mut2)
                content()
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(_ label: String, isOn: Bool, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? colors.invFg : colors.chipFg)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isOn ? colors.invBg : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(isOn ? Color.clear : colors.chipLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityHint(isEnabled ? "" : t("unavailable.hint"))
    }

    private func ratioChip(_ ratio: CaptureRatio, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .stroke(isOn ? colors.invFg : colors.chipFg, lineWidth: 1.5)
                    .frame(width: ratio.iconSize.width, height: ratio.iconSize.height)
                Text(ratio.id)
            }
            .font(.system(size: 11, weight: isOn ? .semibold : .regular))
            .foregroundStyle(isOn ? colors.invFg : colors.chipFg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isOn ? colors.invBg : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(isOn ? Color.clear : colors.chipLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom bar (reference picker / shutter / balance slot)

    private var bottomBar: some View {
        HStack {
            Button {
                showReferencePicker = true
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(colors.fg)
                    .frame(width: 52, height: 52)
                    .background(colors.btnBg, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("a11y.ref"))

            Spacer()

            shutterButton

            Spacer()

            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var shutterButton: some View {
        Button {
            performCapture()
        } label: {
            ZStack {
                Circle()
                    .stroke(colors.shutterRing, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(colors.invBg)
                    .frame(width: 56, height: 56)
            }
        }
        .buttonStyle(.plain)
        .disabled(countdownValue != nil)
        .accessibilityLabel(t("a11y.shutter"))
    }

    private func performCapture() {
        guard countdownValue == nil else { return }
        let seconds = timerOption.rawValue
        guard seconds > 0 else {
            finishCapture()
            return
        }
        Task {
            for remaining in stride(from: seconds, through: 1, by: -1) {
                countdownValue = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            countdownValue = nil
            finishCapture()
        }
    }

    /// When the camera is unavailable and a simulated scene photo is standing in for the
    /// live preview, the shutter hands that photo straight to the review/save sheet instead
    /// of calling into CameraManager, which has no real feed to capture from. Otherwise it
    /// calls the real capture contract with the user's saved preferences, downgrading silent
    /// shutter to off whenever the OS/device combination does not actually support it.
    private func finishCapture() {
        if let simulatedScene {
            saveStatus = nil
            reviewImage = simulatedScene
        } else {
            camera.capturePhoto(
                saveAsPreviewed: saveAsPreviewed,
                suppressShutterSound: silentShutterPreferred && isSilentShutterAvailable
            )
        }
    }

    // MARK: - Reference picker sheet (ported from #boardSheet, presets only)

    private var referencePickerSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t("board.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.fg)
                .padding(.bottom, 14)

            Text(t("board.presets"))
                .font(.system(size: 12))
                .foregroundStyle(colors.mut2)
                .padding(.bottom, 8)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                referenceTile(nil)
                ForEach(ReferencePhoto.samples) { reference in
                    referenceTile(reference)
                }
            }

            Spacer(minLength: 20)

            Button(t("btn.close")) { showReferencePicker = false }
                .buttonStyle(SheetButtonStyle(isPrimary: true, colors: colors))
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(colors.sheet)
    }

    @ViewBuilder
    private func referenceTile(_ reference: ReferencePhoto?) -> some View {
        let isSelected = selectedReference == reference

        Button {
            selectedReference = reference
            showReferencePicker = false
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(colors.fg.opacity(0.06))

                if let reference {
                    referenceThumbnailImage(reference, fallbackColor: colors.chipFg)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "nosign")
                        Text(t("board.none")).font(.system(size: 11))
                    }
                    .foregroundStyle(colors.chipFg)
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accentTint : colors.lineSoft, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result sheet (ported from #resultSheet, single-photo simplification)

    private func resultSheet(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t("result.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.fg)
                .padding(.bottom, 14)

            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(colors.bg)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let saveStatus {
                saveStatusLabel(saveStatus)
                    .padding(.top, 12)
            }

            HStack(spacing: 10) {
                Button(t("result.retake")) {
                    reviewImage = nil
                    saveStatus = nil
                }
                .buttonStyle(SheetButtonStyle(isPrimary: false, colors: colors))

                Button(isSaving ? t("result.saving") : t("result.save")) {
                    Task { await save(image) }
                }
                .buttonStyle(SheetButtonStyle(isPrimary: true, colors: colors))
                .disabled(isSaving)
            }
            .padding(.top, 16)

            Text(t("result.hint"))
                .font(.system(size: 12))
                .foregroundStyle(colors.mut2)
                .padding(.top, 12)
        }
        .padding(20)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(colors.sheet)
    }

    private func saveStatusLabel(_ status: SaveStatus) -> some View {
        Group {
            switch status {
            case .success:
                Label(t("result.saved"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 13, weight: .semibold))
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
}
