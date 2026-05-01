//
//  SleepFlag.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation

/// caffeinate(8) 잠자기 방지 옵션의 도메인 타입
///
/// 과거에는 옵션 식별자가 String("display"/"idle"/"disk"/"ac"/"user")으로 Preferences,
/// Localization, OptionsSection 세 곳에 흩어져 있어 새 옵션을 추가하거나 식별자가 한 곳에서만
/// 바뀌면 다른 곳이 silent하게 어긋나는 위험이 있었다. enum으로 도메인을 일원화해 caffeinate
/// CLI 인자 변환, UserDefaults 키, UI 라벨 매칭, 타이머 의존 여부를 한 자리에서 표현한다
///
/// rawValue는 기존 Localization 사전의 `key` 문자열과 동일하게 유지해 마이그레이션 부담을 없앤다
enum SleepFlag: String, CaseIterable, Identifiable {

    /// 디스플레이 잠자기 방지(`-d`)
    case display

    /// 시스템 유휴 잠자기 방지(`-i`)
    case idle

    /// 디스크 유휴 잠자기 방지(`-m`)
    case disk

    /// AC 전원 잠자기 방지(`-s`)
    case ac

    /// 사용자 활성 선언(`-u`). 타이머와 함께 있을 때만 의미가 있다
    case user

    var id: String { rawValue }

    /// caffeinate(8) CLI 옵션 플래그
    var cliArgument: String {
        switch self {
        case .display: return "-d"
        case .idle: return "-i"
        case .disk: return "-m"
        case .ac: return "-s"
        case .user: return "-u"
        }
    }

    /// 타이머와 함께 있을 때만 의미가 있는 플래그(현재 `-u` 단독)
    ///
    /// caffeinate(8) 매뉴얼은 `-u`가 `-t`와 함께일 때만 동작한다고 명시한다. 무제한 모드에서는
    /// 인자에 포함하지 않는다
    var isTimerOnly: Bool {
        switch self {
        case .user: return true
        case .display, .idle, .disk, .ac: return false
        }
    }

    /// UserDefaults 키. 기존 사용자의 영속화된 값과 호환을 위해 `@AppStorage` 시절의 이름을 그대로 유지한다
    var defaultsKey: String {
        switch self {
        case .display: return "preventDisplaySleep"
        case .idle: return "preventSystemIdleSleep"
        case .disk: return "preventDiskIdleSleep"
        case .ac: return "preventSystemSleepOnAC"
        case .user: return "declareUserActive"
        }
    }

    /// 신규 설치 기본값. 디스플레이/유휴 방지는 ON, 그 외는 OFF
    var defaultValue: Bool {
        switch self {
        case .display, .idle: return true
        case .disk, .ac, .user: return false
        }
    }

    /// UI 토글이 활성화되어야 하는지 결정한다
    ///
    /// `-u`(isTimerOnly)는 caffeinate(8) 매뉴얼상 `-t`와 함께일 때만 동작하지만, 그 사실이
    /// 곧 토글을 항상 잠가야 한다는 뜻은 아니다. 토글 잠금을 풀어두는 게 자연스러운 케이스가 있다
    /// - 비활성 상태: 사용자가 미리 ON으로 설정해 둘 수 있어야 다음 타이머 시작 시 자동 적용된다.
    ///   `arguments(from:timerSeconds:)`가 `hasTimer == false`이면 자동으로 인자에서 제외하므로
    ///   영속화된 ON이 무제한 시작 시 부작용을 일으키지 않는다
    /// - 활성 + 타이머 있음: 즉시 반영 가능하므로 자유롭게 토글한다
    ///
    /// 잠가야 하는 케이스는 정확히 하나뿐이다 - 활성 + 무제한. 이 상태에서는 `-u`를 켜도 caffeinate
    /// 프로세스에 전달되지 않으므로 사용자에게 "켰는데 동작하지 않는" 혼란만 준다.
    /// 그 외 케이스는 모두 토글이 활성화된다(비-isTimerOnly 플래그는 timer 의존이 없어 항상 true)
    static func isToggleEnabled(for flag: SleepFlag, isActive: Bool, timerSeconds: Int) -> Bool {
        guard flag.isTimerOnly else { return true }

        return !isActive || timerSeconds > 0
    }

    /// 옵션 모음을 caffeinate 인자 배열로 변환한다
    ///
    /// - Parameters:
    ///   - preferences: SleepFlag별 ON/OFF 상태를 조회할 수 있는 Preferences 인스턴스
    ///   - timerSeconds: nil이거나 0 이하이면 무제한 모드. 양수이면 `-t {seconds}`를 덧붙인다
    /// - Returns: `-w PID`까지 prepend되지 않은 옵션 인자 배열. 호출 측이 `-w`를 prepend한다
    ///
    /// 빈 배열 반환은 호출 측에서 의미 있는 옵션이 하나도 없는 케이스를 인지해 fallback을
    /// 결정하도록 돕는다(현재 `CaffeinateManager.start(with:)`가 `-i`를 fallback으로 추가).
    ///
    /// `Preferences`가 `@MainActor` 격리이므로 이 함수도 main actor 컨텍스트에서만 호출 가능하다.
    /// 호출 측(`CaffeinateManager`/뷰)은 모두 main actor에서 동작하므로 영향이 없다
    @MainActor
    static func arguments(from preferences: Preferences, timerSeconds: Int?) -> [String] {
        var args: [String] = []
        let hasTimer = (timerSeconds ?? 0) > 0
        for flag in SleepFlag.allCases {
            guard preferences[flag] else { continue }
            if flag.isTimerOnly && !hasTimer { continue }

            args.append(flag.cliArgument)
        }
        if let timerSeconds, timerSeconds > 0 {
            args.append("-t")
            args.append(String(timerSeconds))
        }
        return args
    }
}
