[English](../../../README.md) | **한국어** | [日本語](../ja/README.md)

# caffeine

시스템 `caffeinate` 유틸리티를 글래스모피즘 SwiftUI 패널에서 제어하는 가벼운 macOS 메뉴 바 앱이다. 클릭 한 번으로 Mac을 깨운 상태로 유지하고, 막을 슬립 동작을 개별로 선택하며, 타이머를 고르거나 무제한으로 실행한다.

## Features

- 활성/비활성 아이콘이 있는 원클릭 메뉴 바 토글
- 빠른 타이머 프리셋: 5분, 15분, 30분, 1시간, 2시간, 5시간, 무제한, 또는 시/분 단위 사용자 지정 입력
- 타이머 동작 중 패널에 실시간 카운트다운 표시
- 모든 `caffeinate` 플래그에 대한 개별 토글
  - 디스플레이 슬립 방지(`-d`)
  - 시스템 유휴 슬립 방지(`-i`)
  - 디스크 유휴 슬립 방지(`-m`)
  - AC 전원 사용 시 시스템 슬립 방지(`-s`)
  - 사용자 활동 선언(`-u`, 타이머 필요)
- `SMAppService`를 통한 로그인 시 자동 실행 지원
- 한국어, 영어, 일본어로 현지화된 UI
- 밝은 데스크톱에서도 가독성을 유지하는 다크 글래스 패널과 시스템 강조 색상 자동 적용
- 메뉴 바 전용 - Dock 아이콘 없음, 메인 윈도우 없음

## Components

| Path | Description |
|------|-------------|
| `caffeine/caffeineApp.swift` | `AppDelegate`에 의존성을 연결하는 앱 진입점 |
| `caffeine/AppDelegate.swift` | SwiftUI 콘텐츠를 호스팅하는 `NSStatusItem`과 커스텀 `NSPanel` |
| `caffeine/CaffeinateManager.swift` | `caffeinate` 생명 주기와 카운트다운을 다루는 `Process` 래퍼 |
| `caffeine/Preferences.swift` | `UserDefaults`를 백엔드로 하는 `@Published` 설정과 `caffeinate` 인자 빌더 |
| `caffeine/LoginItemManager.swift` | 로그인 항목 등록을 위한 `SMAppService.mainApp` 래퍼 |
| `caffeine/Localization.swift` | 한국어/영어/일본어 문자열 번들 |
| `caffeine/DesignTokens.swift` | 색상, 간격, 타이포그래피, 모션의 단일 진실 공급원 |
| `caffeine/Views/` | SwiftUI 섹션(헤더, 카운트다운, 옵션, 빠른 타이머)과 공용 컴포넌트 |

## Requirements

- macOS 13 (Ventura) 이상
- 소스에서 빌드하려면 Xcode 16 이상

## Installation

### From a release

1. [최신 릴리즈](https://github.com/binaryloader/caffeine/releases)에서 `caffeine-<version>.dmg`를 내려받는다
2. `.dmg`를 열고 `caffeine.app`을 `/Applications`로 드래그한다
3. 앱은 서명되어 있지 않으므로(Apple Developer Program 미가입) 첫 실행은 Gatekeeper의 차단을 받는다. Finder의 우클릭 메뉴로 한 번 연다
   - `/Applications`의 `caffeine.app`을 우클릭하여 `열기`를 선택한다
   - 대화 상자가 뜨면 `열기`를 한 번 더 클릭하여 확인한다
   - 이후 실행은 메뉴 바에서 정상적으로 동작한다
4. 그래도 대화 상자가 거부하면 격리 속성을 수동으로 제거한다

   ```bash
   xattr -dr com.apple.quarantine /Applications/caffeine.app
   ```

### From source

```bash
git clone https://github.com/binaryloader/caffeine.git
cd caffeine
xcodebuild -project caffeine.xcodeproj -scheme caffeine -configuration Release -destination 'platform=macOS' build
```

컴파일된 번들은 `build/Release/caffeine.app`에 생성된다. 설치하려면 `/Applications`로 옮기면 된다. `caffeine.xcodeproj`를 Xcode에서 열어 `caffeine` 스킴을 직접 실행해도 된다.

## Acknowledgments

이 프로젝트는 [Claude Code](https://claude.com/claude-code)와 함께 개발했다.

## License

This project is licensed under the MIT License - see the [LICENSE](../../../LICENSE) file for details.
