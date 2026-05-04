**English** | [한국어](docs/i18n/ko/README.md) | [日本語](docs/i18n/ja/README.md)

# caffeine

A lightweight macOS menu bar app that controls the system `caffeinate` utility from a glassmorphism SwiftUI panel. Keep your Mac awake with one click, customize which sleep behaviors to prevent, and pick a timer or run indefinitely.

## Features

- One-click menu bar toggle with active and inactive icons
- Quick timer presets: 5m, 15m, 30m, 1h, 2h, 5h, indefinite, or a custom hours/minutes input
- Live countdown displayed in the panel while a timer is running
- Individual toggles for every `caffeinate` flag:
  - Prevent display sleep (`-d`)
  - Prevent system idle sleep (`-i`)
  - Prevent disk idle sleep (`-m`)
  - Prevent system sleep on AC power (`-s`)
  - Declare user activity (`-u`, requires a timer)
- Launch at login support via `SMAppService`
- Localized UI in Korean, English, and Japanese
- Dark glass panel that stays legible on light desktops, with the system accent color applied automatically
- Menu bar only - no Dock icon, no main window

## Components

| Path | Description |
|------|-------------|
| `caffeine/caffeineApp.swift` | App entry point that wires the dependencies into `AppDelegate` |
| `caffeine/AppDelegate.swift` | `NSStatusItem` + custom `NSPanel` host for the SwiftUI content |
| `caffeine/CaffeinateManager.swift` | `Process` wrapper that drives the `caffeinate` lifecycle and countdown |
| `caffeine/Preferences.swift` | `@Published` settings backed by `UserDefaults` and `caffeinate` argument builder |
| `caffeine/LoginItemManager.swift` | `SMAppService.mainApp` wrapper for login-item registration |
| `caffeine/Localization.swift` | Korean / English / Japanese string bundles |
| `caffeine/DesignTokens.swift` | Single source of truth for colors, spacing, typography, and motion |
| `caffeine/Views/` | SwiftUI sections (header, countdown, options, quick timer) and shared components |

## Requirements

- macOS 13 (Ventura) or later
- Xcode 16 or later to build from source

## Installation

### From a release

1. Download `caffeine-<version>.dmg` from the [latest release](https://github.com/binaryloader/caffeine/releases).
2. Open the `.dmg` and drag `caffeine.app` into `/Applications`.
3. The app is unsigned (no Apple Developer Program), so the first launch is gated by Gatekeeper. Open it once with Finder's right-click menu:
   - Right-click `caffeine.app` in `/Applications` and choose `Open`.
   - In the dialog, click `Open` again to confirm.
   Subsequent launches work normally from the menu bar.
4. If the dialog still refuses, remove the quarantine attribute manually:

   ```bash
   xattr -dr com.apple.quarantine /Applications/caffeine.app
   ```

### From source

```bash
git clone https://github.com/binaryloader/caffeine.git
cd caffeine
xcodebuild -project caffeine.xcodeproj -scheme caffeine -configuration Release -destination 'platform=macOS' build
```

The compiled bundle is placed under `build/Release/caffeine.app`. Move it into `/Applications` to install. You can also open `caffeine.xcodeproj` in Xcode and run the `caffeine` scheme directly.

## Acknowledgments

This project was developed with [Claude Code](https://claude.com/claude-code).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
