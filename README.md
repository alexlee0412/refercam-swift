# ReferCam

ReferCam은 레퍼런스 이미지를 카메라 위에 겹쳐 보면서 동일한 구도와 포즈로 사진을 촬영할 수 있는 iOS 카메라 앱입니다.

이 저장소는 ReferCam 웹 프로토타입을 네이티브 Swift / SwiftUI로 다시 구현한 버전입니다.

- 웹 프로토타입: https://heyin-heyout.github.io/refercam/
- 원본 저장소: https://github.com/heyin-heyout/refercam

---

## 주요 기능

- 실시간 카메라 프리뷰 (후면 기본, 전면 전환 가능)
- 레퍼런스 이미지 선택 (Portrait / Street / Café 프리셋 3종 + 안 씀)
- 레퍼런스 투명도 조절 (슬라이더)
- 사진 촬영 및 타이머 (끄기 / 3초 / 5초 / 10초)
- 촬영 비율 선택 (3:4, 4:3, 1:1, 4:5, 5:4, 9:16)
- 촬영 결과 미리보기 (다시 찍기 / 저장)
- 사진 앱에 저장
- Simulator에서 카메라를 쓸 수 없을 때, 화면을 탭해 앨범 사진으로 카메라 화면을 대신 시뮬레이션하는 기능
- 설정 화면 (Settings)
  - 보이는 대로 저장 (전면 카메라 좌우 반전 저장 여부)
  - 무음 셔터 (iOS 18 이상 + 지원 기기에서만)
  - 테마 (다크 / 라이트)
  - 언어 (한국어 / English)

> 아래 기능은 UI만 존재하며 아직 동작하지 않습니다 (이번 버전에서는 비활성화):
> - 영상 촬영 (사진만 지원)
> - 연속 촬영(버스트) 모드
> - 콜라주 / 워터마크 기능
> - 나만의 레퍼런스 사진 업로드 (현재는 기본 제공 프리셋 3종만 선택 가능)

---

## 기술 스택

- Swift 5
- SwiftUI
- AVFoundation (카메라 캡처)
- Photos / PhotosUI (사진 저장, 시뮬레이션용 사진 선택)
- iOS 17.0 이상 (iPhone 전용)
- Xcode

---

## 프로젝트 구조

```text
ReferCam/
├── ReferCamApp.swift          # 앱 진입점
├── CameraView.swift           # 메인 카메라 화면 (UI 전체)
├── SettingsView.swift         # 설정 화면, 테마/다국어, 색상 정의
├── Camera/
│   ├── CameraManager.swift    # AVCaptureSession 제어, 촬영 로직
│   └── CameraPreview.swift    # 카메라 프리뷰 레이어(UIViewRepresentable)
├── Models/
│   └── ReferencePhoto.swift   # 레퍼런스 이미지 모델 및 프리셋 목록
├── Services/
│   └── ImageService.swift     # 사진 앱 저장, 이미지 합성 유틸
└── Assets.xcassets/           # 앱 아이콘, 레퍼런스 프리셋 이미지
```

---

## 설치 및 실행

### 1. 필요한 환경

- macOS
- Xcode (Mac App Store 또는 Apple Developer 사이트에서 설치)
- iOS Simulator: UI 테스트 가능 (macOS만 있으면 됨)
- 실제 카메라 촬영 테스트: 실제 iPhone 필요

### 2. 저장소 클론

```bash
git clone https://github.com/alexlee0412/refercam-swift.git
cd refercam-swift
```

### 3. Xcode Command Line Tools 확인

Xcode를 설치한 뒤, 아래 명령으로 개발 도구가 제대로 연결되어 있는지 확인하세요.

```bash
xcode-select -p
xcodebuild -version
swift --version
```

만약 Xcode는 설치되어 있는데 Command Line Tools가 다른 경로를 가리키고 있다면 아래 명령으로 경로를 맞춰주세요.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

그 다음 다시 확인합니다.

```bash
xcodebuild -version
```

### 4. 프로젝트 열기

아래 파일을 Xcode로 엽니다. (새 Xcode 프로젝트를 만들지 마세요.)

```
ReferCam.xcodeproj
```

터미널에서 바로 열 수도 있습니다.

```bash
open ReferCam.xcodeproj
```

---

## Simulator에서 실행하기

1. Xcode에서 프로젝트를 엽니다.
2. 상단 device selector에서 사용 가능한 iPhone Simulator를 선택합니다.
3. Run 버튼(▶) 또는 `⌘R`을 누릅니다.

터미널에서 사용 가능한 Simulator 목록을 확인할 수 있습니다.

```bash
xcrun simctl list devices available
```

원하는 Simulator를 직접 부팅하고 싶다면 (모델명은 설치된 Xcode에 따라 다를 수 있습니다):

```bash
xcrun simctl boot "iPhone 16"
open -a Simulator
```

> **참고:** iOS Simulator는 실제 iPhone 카메라를 제공하지 않습니다.
> - UI 레이아웃 확인 가능
> - 레퍼런스 선택, 투명도 조절, 설정 화면 등 확인 가능
> - 카메라를 열지 못할 때의 대체(fallback) 동작(화면 탭 → 앨범 사진으로 시뮬레이션) 확인 가능
> - 실제 카메라 촬영은 반드시 실제 iPhone에서 테스트해야 합니다.

---

## 실제 iPhone에서 실행하기

1. iPhone을 USB-C/Lightning 케이블로 Mac에 연결합니다.
2. iPhone 잠금을 해제합니다.
3. "이 컴퓨터를 신뢰하시겠습니까?" 메시지가 뜨면 **신뢰**를 누릅니다.
4. Xcode 상단 device selector에서 연결된 실제 iPhone을 선택합니다.
5. Xcode 왼쪽 프로젝트 네비게이터에서 `ReferCam` 프로젝트를 선택한 뒤 `TARGETS → ReferCam → Signing & Capabilities` 로 이동합니다.
6. `Automatically manage signing`을 체크합니다.
7. Team을 본인의 Apple ID (Personal Team)로 선택합니다.
8. Bundle Identifier를 본인만의 고유한 값으로 바꿉니다. (예: `com.yourname.refercam`)
9. `⌘R`을 눌러 실행합니다.

Xcode가 빌드된 앱을 연결된 iPhone에 직접 설치합니다.

### Developer Mode 켜기

최초 실행 시 iPhone에서 Developer Mode를 켜야 할 수 있습니다. (아이폰이 영어로 설정되어 있을 수 있어 영어 메뉴 경로도 함께 안내합니다.)

```
설정(Settings)
→ 개인정보 보호 및 보안(Privacy & Security)
→ 개발자 모드(Developer Mode)
→ 켬(On)
```

설정 후 iPhone이 재시작될 수 있습니다.

### "신뢰할 수 없는 개발자" 해결

앱 설치 후 실행이 안 되고 "신뢰할 수 없는 개발자"라고 뜨면:

```
설정(Settings)
→ 일반(General)
→ VPN 및 기기 관리(VPN & Device Management)
→ 개발자 앱(Developer App)
→ 신뢰(Trust)
```

여기 표시되는 Apple ID / 개발자 이름은 본인 계정에 따라 다르게 보입니다.

### Apple ID / 무료 계정으로도 되나요?

본인의 iPhone에서 Xcode로 앱을 실행해보는 데에는 **유료 Apple Developer Program 가입이 필요하지 않습니다.** 일반 Apple ID(Personal Team)로 개발용 테스트가 가능합니다.

> App Store 배포나 TestFlight 배포에는 Apple Developer Program 가입이 필요합니다.

---

## CLI로 빌드 확인하기

프로젝트 정보(타겟/스킴)를 확인합니다.

```bash
xcodebuild -project ReferCam.xcodeproj -list
```

Simulator용으로 빌드가 되는지 확인합니다.

```bash
xcodebuild \
  -project ReferCam.xcodeproj \
  -scheme ReferCam \
  -sdk iphonesimulator \
  -configuration Debug \
  build
```

출력 마지막에 아래 문구가 보이면 빌드 성공입니다.

```
** BUILD SUCCEEDED **
```

---

## 권한

앱을 사용하면서 아래 두 가지 iOS 권한 요청을 보게 됩니다.

- **카메라(Camera)** — 사진 촬영을 위해 필요합니다.
- **사진 보관함 추가(Add to Photo Library)** — 촬영한 사진을 사진 앱에 저장하기 위해 필요합니다.

각 기능을 처음 사용할 때 iOS가 표준 권한 요청 팝업을 띄워줍니다. 별도 설정은 필요하지 않습니다.

---

## 문제 해결

**"Your team has no devices from which to generate a provisioning profile"**
보통 아직 등록된 실제 iPhone이 없다는 뜻입니다. iPhone을 연결 → 잠금 해제 → 신뢰 후, Xcode의 Run Destination으로 선택하고 `Signing & Capabilities`를 다시 확인하세요.

**iPhone이 Xcode에 안 보임**
- 케이블이 제대로 연결되어 있는지 확인
- iPhone 잠금 해제 여부 확인
- "이 컴퓨터를 신뢰" 메시지에 신뢰를 눌렀는지 확인
- Xcode → Window → Devices and Simulators (Manage Devices)에서 인식 여부 확인

터미널에서도 확인할 수 있습니다.

```bash
xcrun devicectl list devices
```

**"신뢰할 수 없는 개발자(Untrusted Developer)"**
위의 [신뢰할 수 없는 개발자 해결](#신뢰할-수-없는-개발자-해결) 항목을 참고하세요.

**Developer Mode가 필요하다고 나옴**
위의 [Developer Mode 켜기](#developer-mode-켜기) 항목을 참고하세요.

**Simulator에서 카메라 오류가 남**
iOS Simulator는 실제 iPhone과 동일한 카메라 환경을 제공하지 않습니다. 실제 카메라 촬영 테스트는 반드시 실제 iPhone에서 진행해주세요.

**`xcodebuild`가 Xcode를 못 찾음**

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## 개발 시 참고

- 네이티브 SwiftUI로 구현되어 있습니다.
- 카메라 관련 코드는 `Camera/` 폴더에 있습니다.
- 화면 UI는 주로 `CameraView.swift`, `SettingsView.swift`에 있습니다.
- 레퍼런스 프리셋 이미지는 `Assets.xcassets`에 저장되어 있습니다.
- 현재 MVP는 별도 백엔드 서버 없이 동작합니다.

---

## 원본 ReferCam

- 웹 프로토타입: https://heyin-heyout.github.io/refercam/
- 원본 웹 소스: https://github.com/heyin-heyout/refercam

이 네이티브 버전은 Swift / SwiftUI로 동일한 제품 경험을 재현하는 것을 목표로 합니다.
