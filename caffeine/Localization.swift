//
//  Localization.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation

/// 앱이 지원하는 UI 언어
///
/// 메뉴바 앱 내에서 즉시 전환되어야 하므로 SwiftUI 표준 Localizable.strings 대신
/// 단일 Swift 사전을 사용한다. 선택된 언어는 `Preferences.appLanguageRaw`를 통해 UserDefaults에 영속화된다
enum AppLanguage: String, CaseIterable {

    case ko
    case en
    case ja

    /// 시스템 로케일에서 기본 언어를 선택한다. ko/ja 외에는 en으로 폴백한다
    static func defaultFromSystem() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("ko") { return .ko }
        if preferred.hasPrefix("ja") { return .ja }

        return .en
    }

    /// 언어 segmented control 칩에 표시되는 짧은 라벨(KO/EN/JA)
    ///
    /// 언어 식별자라 번역 대상이 아니며 모든 로케일에서 동일하게 표기한다
    var shortLabel: String {
        switch self {
        case .ko: return "KO"
        case .en: return "EN"
        case .ja: return "JA"
        }
    }
}

/// 한 언어의 모든 사용자 노출 문자열
///
/// 디자인 핸드오프 README와 Caffeine.html 프로토타입의 i18n 사전을 1:1 매핑한다
struct LocalizedStrings {

    /// 한 caffeinate 옵션 행에 표시되는 라벨/설명 묶음
    ///
    /// 옵션 식별자(이전의 `key: String`)는 `SleepFlag` enum으로 타입화되었으며 CLI 플래그
    /// (`-d` 등)는 `SleepFlag.cliArgument`로 일원화되었다. 사용자에게 표시할 라벨/설명만
    /// 언어별로 분기되므로 두 필드만 남긴다
    struct FlagText {

        /// 옵션 식별자
        let flag: SleepFlag

        /// 사용자에게 보여줄 옵션명
        let label: String

        /// 옵션 설명 한 줄
        let description: String
    }

    /// Quick Timer 칩 라벨
    struct TimerLabels {

        let infinity: String
        let fiveMinutes: String
        let fifteenMinutes: String
        let thirtyMinutes: String
        let oneHour: String
        let twoHours: String
        let fiveHours: String
    }

    let active: String
    let inactive: String
    let left: String
    let quickTimer: String
    let options: String
    let custom: String
    let customTimer: String
    let cancel: String
    let start: String
    let hours: String
    let minutes: String
    let language: String
    let quit: String
    let appSettings: String
    let launchAtLogin: String
    let launchAtLoginDescription: String
    /// 로그인 시 자동 시작 등록/해제가 실패했을 때 표시할 보조 안내
    let launchAtLoginErrorHint: String
    /// GitHub 푸터 크레딧의 접근성 라벨에 쓰는 "GitHub 프로필" 문구
    let githubProfile: String
    /// 헤더 메인 토글 접근성 라벨
    let mainToggleAccessibilityLabel: String
    /// 옵션 패널이 펼쳐진 상태의 접근성 value
    let optionsExpandedAccessibility: String
    /// 옵션 패널이 접힌 상태의 접근성 value
    let optionsCollapsedAccessibility: String
    /// 타이머 프리셋 칩의 접근성 hint("탭하여 타이머 시작")
    let timerPresetAccessibilityHint: String
    /// 토글 ON 상태 접근성 value
    let toggleOnAccessibility: String
    /// 토글 OFF 상태 접근성 value
    let toggleOffAccessibility: String
    /// 자동 시작 토글 접근성 라벨
    let launchAtLoginAccessibilityLabel: String
    /// 언어 선택 접근성 라벨
    let languageAccessibilityLabel: String
    let timerLabels: TimerLabels
    let flags: [FlagText]
}

/// 언어별 LocalizedStrings 사전을 보관한다
enum Localizations {

    /// 주어진 언어의 문자열 묶음을 반환한다
    static func strings(for language: AppLanguage) -> LocalizedStrings {
        switch language {
        case .en: return english
        case .ko: return korean
        case .ja: return japanese
        }
    }

    private static let english = LocalizedStrings(
        active: "Active",
        inactive: "Inactive",
        left: "left",
        quickTimer: "Quick Timer",
        options: "Options",
        custom: "Custom",
        customTimer: "Custom Timer",
        cancel: "Cancel",
        start: "Start",
        hours: "Hours",
        minutes: "Minutes",
        language: "Language",
        quit: "Quit",
        appSettings: "App Settings",
        launchAtLogin: "Launch at login",
        launchAtLoginDescription: "Open caffeine automatically when you log in",
        launchAtLoginErrorHint: "Approval required in System Settings",
        githubProfile: "GitHub profile",
        mainToggleAccessibilityLabel: "Caffeine activation toggle",
        optionsExpandedAccessibility: "Expanded",
        optionsCollapsedAccessibility: "Collapsed",
        timerPresetAccessibilityHint: "Tap to start timer",
        toggleOnAccessibility: "On",
        toggleOffAccessibility: "Off",
        launchAtLoginAccessibilityLabel: "Launch at login toggle",
        languageAccessibilityLabel: "Language selector",
        timerLabels: LocalizedStrings.TimerLabels(
            infinity: "∞",
            fiveMinutes: "5m",
            fifteenMinutes: "15m",
            thirtyMinutes: "30m",
            oneHour: "1h",
            twoHours: "2h",
            fiveHours: "5h"
        ),
        flags: [
            LocalizedStrings.FlagText(
                flag: .display,
                label: "Prevent display sleep",
                description: "Keeps the display from turning off"
            ),
            LocalizedStrings.FlagText(
                flag: .idle,
                label: "Prevent idle sleep",
                description: "Keeps your Mac awake even when idle"
            ),
            LocalizedStrings.FlagText(
                flag: .disk,
                label: "Prevent disk idle sleep",
                description: "Keeps hard drives spinning"
            ),
            LocalizedStrings.FlagText(
                flag: .ac,
                label: "Prevent sleep on AC",
                description: "Stays awake only while plugged in"
            ),
            LocalizedStrings.FlagText(
                flag: .user,
                label: "Declare user active",
                description: "Resets idle timers as if you're active"
            )
        ]
    )

    private static let korean = LocalizedStrings(
        active: "활성",
        inactive: "비활성",
        left: "남음",
        quickTimer: "빠른 타이머",
        options: "옵션",
        custom: "사용자 지정",
        customTimer: "사용자 지정 타이머",
        cancel: "취소",
        start: "시작",
        hours: "시간",
        minutes: "분",
        language: "언어",
        quit: "종료",
        appSettings: "앱 설정",
        launchAtLogin: "로그인 시 자동 시작",
        launchAtLoginDescription: "Mac에 로그인하면 Caffeine을 자동으로 실행",
        launchAtLoginErrorHint: "시스템 설정에서 허용이 필요합니다",
        githubProfile: "GitHub 프로필",
        mainToggleAccessibilityLabel: "Caffeine 활성화 토글",
        optionsExpandedAccessibility: "확장됨",
        optionsCollapsedAccessibility: "축소됨",
        timerPresetAccessibilityHint: "탭하여 타이머 시작",
        toggleOnAccessibility: "켜짐",
        toggleOffAccessibility: "꺼짐",
        launchAtLoginAccessibilityLabel: "로그인 시 자동 시작 토글",
        languageAccessibilityLabel: "언어 선택",
        timerLabels: LocalizedStrings.TimerLabels(
            infinity: "∞",
            fiveMinutes: "5분",
            fifteenMinutes: "15분",
            thirtyMinutes: "30분",
            oneHour: "1시간",
            twoHours: "2시간",
            fiveHours: "5시간"
        ),
        flags: [
            LocalizedStrings.FlagText(
                flag: .display,
                label: "디스플레이 잠자기 방지",
                description: "화면이 꺼지지 않게 유지"
            ),
            LocalizedStrings.FlagText(
                flag: .idle,
                label: "유휴 잠자기 방지",
                description: "사용하지 않아도 Mac을 깨어 있게 유지"
            ),
            LocalizedStrings.FlagText(
                flag: .disk,
                label: "디스크 유휴 잠자기 방지",
                description: "하드 드라이브가 멈추지 않게 유지"
            ),
            LocalizedStrings.FlagText(
                flag: .ac,
                label: "AC 전원 잠자기 방지",
                description: "전원 연결 시에만 깨어 있게 유지"
            ),
            LocalizedStrings.FlagText(
                flag: .user,
                label: "사용자 활성 선언",
                description: "사용자가 작업 중인 것처럼 유휴 타이머 초기화"
            )
        ]
    )

    private static let japanese = LocalizedStrings(
        active: "アクティブ",
        inactive: "非アクティブ",
        left: "残り",
        quickTimer: "クイックタイマー",
        options: "オプション",
        custom: "カスタム",
        customTimer: "カスタムタイマー",
        cancel: "キャンセル",
        start: "開始",
        hours: "時間",
        minutes: "分",
        language: "言語",
        quit: "終了",
        appSettings: "アプリ設定",
        launchAtLogin: "ログイン時に自動起動",
        launchAtLoginDescription: "Macにログインすると Caffeine を自動的に開く",
        launchAtLoginErrorHint: "システム設定での許可が必要です",
        githubProfile: "GitHub プロフィール",
        mainToggleAccessibilityLabel: "Caffeine 有効化トグル",
        optionsExpandedAccessibility: "展開済み",
        optionsCollapsedAccessibility: "折りたたみ済み",
        timerPresetAccessibilityHint: "タップしてタイマー開始",
        toggleOnAccessibility: "オン",
        toggleOffAccessibility: "オフ",
        launchAtLoginAccessibilityLabel: "ログイン時に自動起動トグル",
        languageAccessibilityLabel: "言語選択",
        timerLabels: LocalizedStrings.TimerLabels(
            infinity: "∞",
            fiveMinutes: "5分",
            fifteenMinutes: "15分",
            thirtyMinutes: "30分",
            oneHour: "1時間",
            twoHours: "2時間",
            fiveHours: "5時間"
        ),
        flags: [
            LocalizedStrings.FlagText(
                flag: .display,
                label: "ディスプレイスリープ防止",
                description: "画面が消灯しないようにする"
            ),
            LocalizedStrings.FlagText(
                flag: .idle,
                label: "アイドルスリープ防止",
                description: "使っていなくても Mac を起こしたままにする"
            ),
            LocalizedStrings.FlagText(
                flag: .disk,
                label: "ディスクアイドルスリープ防止",
                description: "ハードディスクが停止しないようにする"
            ),
            LocalizedStrings.FlagText(
                flag: .ac,
                label: "AC電源スリープ防止",
                description: "電源接続中のみ起動状態を維持"
            ),
            LocalizedStrings.FlagText(
                flag: .user,
                label: "ユーザーアクティブ宣言",
                description: "操作中のように扱われアイドルタイマーをリセット"
            )
        ]
    )
}
