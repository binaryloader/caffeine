[English](../../../README.md) | [한국어](../ko/README.md) | **日本語**

# caffeine

システムの`caffeinate`ユーティリティをグラスモーフィズムのSwiftUIパネルから操作する軽量なmacOSメニューバーアプリです。ワンクリックでMacをスリープさせず、防止するスリープ動作を個別にカスタマイズし、タイマーを選ぶか無制限に実行できます。

## Features

- アクティブ／非アクティブアイコン付きのワンクリックメニューバートグル
- クイックタイマープリセット：5分、15分、30分、1時間、2時間、5時間、無制限、または時／分単位のカスタム入力
- タイマー稼働中はパネルにリアルタイムのカウントダウンを表示
- すべての`caffeinate`フラグに対する個別トグル
  - ディスプレイスリープを防ぐ(`-d`)
  - システムアイドルスリープを防ぐ(`-i`)
  - ディスクアイドルスリープを防ぐ(`-m`)
  - AC電源使用時のシステムスリープを防ぐ(`-s`)
  - ユーザーアクティビティを宣言(`-u`、タイマーが必要)
- `SMAppService`を介したログイン時自動起動のサポート
- 日本語、英語、韓国語にローカライズされたUI
- 明るいデスクトップでも視認性を保つダークなグラスパネルと、システムアクセントカラーの自動適用
- メニューバー専用 - Dockアイコンなし、メインウィンドウなし

## Components

| Path | Description |
|------|-------------|
| `caffeine/caffeineApp.swift` | 依存関係を`AppDelegate`に組み込むアプリのエントリーポイント |
| `caffeine/AppDelegate.swift` | SwiftUIコンテンツをホストする`NSStatusItem`とカスタム`NSPanel` |
| `caffeine/CaffeinateManager.swift` | `caffeinate`のライフサイクルとカウントダウンを駆動する`Process`ラッパー |
| `caffeine/Preferences.swift` | `UserDefaults`に支えられた`@Published`設定と`caffeinate`引数ビルダー |
| `caffeine/LoginItemManager.swift` | ログイン項目登録のための`SMAppService.mainApp`ラッパー |
| `caffeine/Localization.swift` | 韓国語／英語／日本語の文字列バンドル |
| `caffeine/DesignTokens.swift` | カラー、スペーシング、タイポグラフィ、モーションの単一情報源 |
| `caffeine/Views/` | SwiftUIセクション(ヘッダー、カウントダウン、オプション、クイックタイマー)と共有コンポーネント |

## Requirements

- macOS 13 (Ventura) 以降
- ソースからビルドする場合はXcode 16以降

## Installation

### From a release

1. [最新リリース](https://github.com/binaryloader/caffeine/releases)から`caffeine-<version>.dmg`をダウンロードします
2. `.dmg`を開き、`caffeine.app`を`/Applications`にドラッグします
3. アプリは署名されていない(Apple Developer Program未加入)ため、初回起動はGatekeeperによって制限されます。Finderの右クリックメニューから一度開きます
   - `/Applications`内の`caffeine.app`を右クリックし、`開く`を選択します
   - 表示されるダイアログで再度`開く`をクリックして確定します
   - 以降の起動はメニューバーから通常通り動作します
4. それでもダイアログが拒否する場合は、隔離属性を手動で削除します

   ```bash
   xattr -dr com.apple.quarantine /Applications/caffeine.app
   ```

### From source

```bash
git clone https://github.com/binaryloader/caffeine.git
cd caffeine
xcodebuild -project caffeine.xcodeproj -scheme caffeine -configuration Release -destination 'platform=macOS' build
```

コンパイルされたバンドルは`build/Release/caffeine.app`に配置されます。インストールするには`/Applications`に移動します。`caffeine.xcodeproj`をXcodeで開き、`caffeine`スキームを直接実行することもできます。

## Acknowledgments

このプロジェクトは[Claude Code](https://claude.com/claude-code)とともに開発しました。

## License

This project is licensed under the MIT License - see the [LICENSE](../../../LICENSE) file for details.
