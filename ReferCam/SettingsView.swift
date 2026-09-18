import SwiftUI

// MARK: - Preferences (AppStorage-backed; keys are shared with CameraView so both
// views read/write the same persisted values without a mediating object)

enum AppTheme: String, CaseIterable {
    case dark, light

    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
}

enum AppLanguage: String, CaseIterable {
    case ko, en

    static func systemDefault() -> AppLanguage {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return code.hasPrefix("ko") ? .ko : .en
    }
}

enum AppStorageKey {
    static let silentShutterPreferred = "refcam.silentShutterPreferred"
    static let theme = "refcam.theme"
    static let language = "refcam.language"
}

/// Amber accent used for selection states; identical in both themes in the source CSS
/// (`#f2b544` is a hardcoded literal, never a themed variable), so it needs no variants.
let accentTint = Color(red: 0xf2 / 255.0, green: 0xb5 / 255.0, blue: 0x44 / 255.0)

// MARK: - Central string table (runtime Korean/English switching, no duplicated screens)

enum L10n {
    private static let table: [String: (ko: String, en: String)] = [
        "mode.instant": ("바로 콜라주", "Instant"),
        "mode.burst": ("연속 촬영", "Burst"),
        "a11y.settings": ("설정", "Settings"),
        "a11y.switchCam": ("카메라 전환", "Switch camera"),
        "stage.hint.silent": ("레퍼런스 없이도 무음 카메라로 촬영돼요", "Silent capture — works without a reference too"),
        "stage.hint.plain": ("레퍼런스 없이도 촬영돼요", "Works without a reference too"),
        "cam.fail": ("카메라를 못 열었어요. 화면을 탭해 장면 사진으로 시뮬레이션하세요.", "Couldn't open the camera. Tap the screen to simulate with a scene photo."),
        "cam.denied": ("카메라 접근이 꺼져 있어요. 탭해서 설정을 여세요.", "Camera access is off. Tap to open Settings."),
        "a11y.currentRef": ("현재 레퍼런스", "Current reference"),
        "row.shoot": ("촬영", "Shoot"),
        "chip.photo": ("사진", "Photo"),
        "chip.video": ("영상", "Video"),
        "row.ratio": ("비율", "Ratio"),
        "row.timer": ("타이머", "Timer"),
        "timer.off": ("끄기", "Off"),
        "timer.3": ("3초", "3s"),
        "timer.5": ("5초", "5s"),
        "timer.10": ("10초", "10s"),
        "row.opacity": ("투명도", "Opacity"),
        "a11y.ref": ("레퍼런스", "Reference"),
        "a11y.shutter": ("촬영", "Shutter"),
        "board.title": ("레퍼런스 보드", "Reference board"),
        "board.presets": ("프리셋 구도", "Preset compositions"),
        "board.none": ("없음", "None"),
        "btn.close": ("닫기", "Close"),
        "unavailable.hint": ("이번 버전에서는 사용할 수 없어요", "Not available in this version"),
        "result.title": ("사진 촬영됨", "Photo captured"),
        "result.retake": ("계속 촬영", "Keep shooting"),
        "result.save": ("저장", "Save"),
        "result.saving": ("저장 중…", "Saving…"),
        "result.saved": ("사진에 저장됨", "Saved to Photos"),
        "result.hint": (
            "자동으로 저장되지 않으면 사진을 길게 눌러 \"사진에 저장\"을 선택하세요.",
            "If saving doesn't start automatically, press and hold the photo and choose Save to Photos."
        ),
        "set.title": ("설정", "Settings"),
        "set.camera": ("카메라 설정", "Camera"),
        "set.display": ("화면", "Display"),
        "set.collage": ("콜라주", "Collage"),
        "set.silent": ("무음 셔터", "Silent shutter"),
        "set.silentD": ("지원되는 기기에서 무음 촬영이 적용돼요", "Silent capture when supported"),
        "set.silentUnavailable": ("iOS 18 이상 및 지원 기기에서만 사용할 수 있어요", "Requires iOS 18 or later on a supported device"),
        "set.theme": ("테마", "Theme"),
        "set.themeD": ("뷰파인더는 항상 어둡게 유지돼요", "The viewfinder always stays dark"),
        "set.lang": ("언어", "Language"),
        "set.langD": ("앱에 표시되는 언어", "App display language"),
        "theme.dark": ("다크", "Dark"),
        "theme.light": ("라이트", "Light"),
        "set.wm": ("워터마크 표시", "Show watermark"),
        "set.wmD": ("이번 버전에서는 콜라주 기능을 사용할 수 없어요", "Collage isn't available in this version")
    ]

    static func t(_ key: String, _ language: AppLanguage) -> String {
        guard let pair = table[key] else { return key }
        return language == .ko ? pair.ko : pair.en
    }
}

// MARK: - Chrome palette (ported from the prototype's CSS custom properties; this is
// the theme-reactive half of the UI. The stage/viewfinder keeps its own fixed-dark
// colors in CameraView's StagePalette regardless of this setting.)

struct ChromeColors {
    let bg: Color
    let fg: Color
    let mut: Color
    let mut2: Color
    let line: Color
    let lineSoft: Color
    let lineSofter: Color
    let chipLine: Color
    let chipFg: Color
    let invBg: Color
    let invFg: Color
    let seg: Color
    let btnBg: Color
    let sheet: Color
    let shutterRing: Color

    static func resolved(for theme: AppTheme) -> ChromeColors {
        theme == .dark ? .dark : .light
    }

    static let dark = ChromeColors(
        bg: Color(red: 0x0c / 255.0, green: 0x0c / 255.0, blue: 0x0d / 255.0),
        fg: Color(red: 0xf2 / 255.0, green: 0xf2 / 255.0, blue: 0xf0 / 255.0),
        mut: Color(red: 0x9a / 255.0, green: 0x9a / 255.0, blue: 0x94 / 255.0),
        mut2: Color(red: 0x83 / 255.0, green: 0x83 / 255.0, blue: 0x7d / 255.0),
        line: Color.white.opacity(0.2),
        lineSoft: Color.white.opacity(0.14),
        lineSofter: Color.white.opacity(0.07),
        chipLine: Color.white.opacity(0.18),
        chipFg: Color(red: 0xb7 / 255.0, green: 0xb7 / 255.0, blue: 0xb0 / 255.0),
        invBg: Color(red: 0xf2 / 255.0, green: 0xf2 / 255.0, blue: 0xf0 / 255.0),
        invFg: Color(red: 0x0c / 255.0, green: 0x0c / 255.0, blue: 0x0d / 255.0),
        seg: Color.white.opacity(0.08),
        btnBg: Color.white.opacity(0.06),
        sheet: Color(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x1a / 255.0),
        shutterRing: Color.white.opacity(0.85)
    )

    static let light = ChromeColors(
        bg: Color(red: 0xf4 / 255.0, green: 0xf2 / 255.0, blue: 0xec / 255.0),
        fg: Color(red: 0x1b / 255.0, green: 0x1a / 255.0, blue: 0x16 / 255.0),
        mut: Color(red: 0x77 / 255.0, green: 0x75 / 255.0, blue: 0x6c / 255.0),
        mut2: Color(red: 0x8a / 255.0, green: 0x88 / 255.0, blue: 0x7f / 255.0),
        line: Color.black.opacity(0.25),
        lineSoft: Color.black.opacity(0.14),
        lineSofter: Color.black.opacity(0.09),
        chipLine: Color.black.opacity(0.2),
        chipFg: Color(red: 0x55 / 255.0, green: 0x53 / 255.0, blue: 0x4b / 255.0),
        invBg: Color(red: 0x1b / 255.0, green: 0x1a / 255.0, blue: 0x16 / 255.0),
        invFg: Color(red: 0xf7 / 255.0, green: 0xf7 / 255.0, blue: 0xf4 / 255.0),
        seg: Color.black.opacity(0.07),
        btnBg: Color.black.opacity(0.05),
        sheet: Color(red: 0xfb / 255.0, green: 0xfa / 255.0, blue: 0xf6 / 255.0),
        shutterRing: Color(red: 20 / 255.0, green: 20 / 255.0, blue: 16 / 255.0).opacity(0.8)
    )
}

// MARK: - Shared sheet button style (ported from .btn / .btn.primary, theme-aware)

struct SheetButtonStyle: ButtonStyle {
    let isPrimary: Bool
    let colors: ChromeColors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: isPrimary ? .semibold : .regular))
            .foregroundStyle(isPrimary ? colors.invFg : colors.fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(isPrimary ? colors.invBg : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPrimary ? Color.clear : colors.line, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Toggle switch (ported from .toggle / .toggle::after / .toggle.on)

private struct ToggleSwitch: View {
    let isOn: Bool
    let isEnabled: Bool
    let trackOffColor: Color
    let action: () -> Void

    private let onColor = Color(red: 0x7e / 255.0, green: 0xd9 / 255.0, blue: 0x57 / 255.0)
    private let thumbColor = Color(red: 0xf2 / 255.0, green: 0xf2 / 255.0, blue: 0xf0 / 255.0)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? onColor : trackOffColor)
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(thumbColor)
                    .frame(width: 24, height: 24)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

// MARK: - Compact segmented pills (ported from .seg, generic over the option type)

private struct SegmentedPills<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    let selection: Value
    let colors: ChromeColors
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                Button {
                    onSelect(option.value)
                } label: {
                    Text(option.label)
                        .lineLimit(1)
                        .fixedSize()
                        .font(.system(size: 11, weight: selection == option.value ? .semibold : .regular))
                        .foregroundStyle(selection == option.value ? colors.invFg : colors.mut)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selection == option.value ? colors.invBg : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(colors.seg, in: Capsule())
    }
}

// MARK: - Settings row (ported from .set-row: title 15 + description 12, bottom hairline)

private struct SettingsRow<Trailing: View>: View {
    let title: String
    let description: String
    let colors: ChromeColors
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(colors.fg)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(colors.mut2)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(colors.lineSofter).frame(height: 1)
        }
    }
}

private struct SectionLabel: View {
    let title: String
    let colors: ChromeColors

    var body: some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundStyle(colors.mut2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @AppStorage(AppStorageKey.silentShutterPreferred) private var silentShutterPreferred: Bool = true
    @AppStorage(AppStorageKey.theme) private var themeRaw: String = AppTheme.dark.rawValue
    @AppStorage(AppStorageKey.language) private var languageRaw: String = AppLanguage.systemDefault().rawValue

    @Environment(\.dismiss) private var dismiss

    /// Combined "iOS 18+ AND device support" capability, computed by CameraView from
    /// CameraManager.isShutterSoundSuppressionSupported and passed in.
    let isSilentShutterSupported: Bool

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .dark }
    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }
    private var colors: ChromeColors { ChromeColors.resolved(for: theme) }

    private func t(_ key: String) -> String { L10n.t(key, language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t("set.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.fg)
                .padding(.bottom, 14)

            // Rows scroll independently of the sheet's detent, and Close stays pinned
            // below the scroll area, so all rows and Close are reachable whether the
            // sheet is at .medium or .large, on any iPhone size or Dynamic Type setting.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(title: t("set.camera"), colors: colors)

                    SettingsRow(
                        title: t("set.silent"),
                        description: isSilentShutterSupported ? t("set.silentD") : t("set.silentUnavailable"),
                        colors: colors
                    ) {
                        ToggleSwitch(isOn: silentShutterPreferred, isEnabled: isSilentShutterSupported, trackOffColor: colors.line) {
                            silentShutterPreferred.toggle()
                        }
                    }

                    SectionLabel(title: t("set.display"), colors: colors)

                    SettingsRow(title: t("set.theme"), description: t("set.themeD"), colors: colors) {
                        SegmentedPills(
                            options: [(AppTheme.dark, t("theme.dark")), (AppTheme.light, t("theme.light"))],
                            selection: theme,
                            colors: colors
                        ) { newValue in
                            themeRaw = newValue.rawValue
                        }
                    }

                    SettingsRow(title: t("set.lang"), description: t("set.langD"), colors: colors) {
                        // Language option labels are always shown in their own native script
                        // (matching the prototype's raw "한국어" / "English" labels), never
                        // translated through L10n, so a reader can find their language either way.
                        SegmentedPills(
                            options: [(AppLanguage.ko, "한국어"), (AppLanguage.en, "English")],
                            selection: language,
                            colors: colors
                        ) { newValue in
                            languageRaw = newValue.rawValue
                        }
                    }

                    SectionLabel(title: t("set.collage"), colors: colors)

                    SettingsRow(title: t("set.wm"), description: t("set.wmD"), colors: colors) {
                        ToggleSwitch(isOn: false, isEnabled: false, trackOffColor: colors.line) {}
                    }
                }
            }

            Button(t("btn.close")) {
                dismiss()
            }
            .buttonStyle(SheetButtonStyle(isPrimary: true, colors: colors))
            .padding(.top, 16)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.sheet)
        // Tall by default so the row hierarchy is visible on open, matching the source's
        // tall bottom sheet (max-height: 92dvh) rather than a half-height sheet that
        // clips it. Rows still scroll and Close stays reachable regardless of detent
        // (see the ScrollView above).
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(colors.sheet)
    }
}
