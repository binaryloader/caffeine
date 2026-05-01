//
//  SleepFlagTests.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import XCTest
@testable import caffeine

/// `SleepFlag` enum의 도메인 매핑 검증
///
/// 새 옵션 추가 시 cliArgument/defaultsKey/isTimerOnly 한 곳만 어긋나도 회귀가 발생하므로
/// 모든 case에 대해 5종 매핑을 잠근다
final class SleepFlagTests: XCTestCase {

    // MARK: - cliArgument

    func test_cliArgument_매핑이_caffeinate_매뉴얼과_일치한다() {
        XCTAssertEqual(SleepFlag.display.cliArgument, "-d")
        XCTAssertEqual(SleepFlag.idle.cliArgument, "-i")
        XCTAssertEqual(SleepFlag.disk.cliArgument, "-m")
        XCTAssertEqual(SleepFlag.ac.cliArgument, "-s")
        XCTAssertEqual(SleepFlag.user.cliArgument, "-u")
    }

    // MARK: - isTimerOnly

    func test_isTimerOnly는_user_단독으로_true이고_나머지는_false() {
        XCTAssertTrue(SleepFlag.user.isTimerOnly)
        XCTAssertFalse(SleepFlag.display.isTimerOnly)
        XCTAssertFalse(SleepFlag.idle.isTimerOnly)
        XCTAssertFalse(SleepFlag.disk.isTimerOnly)
        XCTAssertFalse(SleepFlag.ac.isTimerOnly)
    }

    // MARK: - defaultsKey

    func test_defaultsKey는_AppStorage_시절_이름을_그대로_유지한다() {
        // 기존 사용자의 영속화된 값과 호환을 보장하기 위한 검증.
        // 이 테스트가 실패한다는 것은 실사용자의 토글 상태가 리셋된다는 뜻이다
        XCTAssertEqual(SleepFlag.display.defaultsKey, "preventDisplaySleep")
        XCTAssertEqual(SleepFlag.idle.defaultsKey, "preventSystemIdleSleep")
        XCTAssertEqual(SleepFlag.disk.defaultsKey, "preventDiskIdleSleep")
        XCTAssertEqual(SleepFlag.ac.defaultsKey, "preventSystemSleepOnAC")
        XCTAssertEqual(SleepFlag.user.defaultsKey, "declareUserActive")
    }

    // MARK: - allCases

    func test_allCases가_5개이며_식별자가_고유하다() {
        XCTAssertEqual(SleepFlag.allCases.count, 5)
        let ids = Set(SleepFlag.allCases.map(\.id))
        XCTAssertEqual(ids.count, 5)
        let cliArgs = Set(SleepFlag.allCases.map(\.cliArgument))
        XCTAssertEqual(cliArgs.count, 5)
        let defaultsKeys = Set(SleepFlag.allCases.map(\.defaultsKey))
        XCTAssertEqual(defaultsKeys.count, 5)
    }

    // MARK: - defaultValue

    func test_defaultValue는_display_idle만_true이다() {
        XCTAssertTrue(SleepFlag.display.defaultValue)
        XCTAssertTrue(SleepFlag.idle.defaultValue)
        XCTAssertFalse(SleepFlag.disk.defaultValue)
        XCTAssertFalse(SleepFlag.ac.defaultValue)
        XCTAssertFalse(SleepFlag.user.defaultValue)
    }

    // MARK: - arguments(from:timerSeconds:)

    @MainActor
    func test_모든_옵션_OFF_타이머_nil이면_빈_배열을_반환한다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        let args = SleepFlag.arguments(from: prefs, timerSeconds: nil)
        XCTAssertTrue(args.isEmpty)
    }

    @MainActor
    func test_display만_ON이고_타이머_nil이면_dash_d만_반환한다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.display] = true
        let args = SleepFlag.arguments(from: prefs, timerSeconds: nil)
        XCTAssertEqual(args, ["-d"])
    }

    @MainActor
    func test_user_ON_타이머_nil이면_dash_u가_제외된다() {
        // -u는 isTimerOnly이므로 타이머가 없으면 인자에 포함되지 않는다
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.user] = true
        let args = SleepFlag.arguments(from: prefs, timerSeconds: nil)
        XCTAssertFalse(args.contains("-u"))
    }

    @MainActor
    func test_user_ON_타이머_300이면_dash_u_dash_t_300이_포함된다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.user] = true
        let args = SleepFlag.arguments(from: prefs, timerSeconds: 300)
        XCTAssertEqual(args, ["-u", "-t", "300"])
    }

    @MainActor
    func test_모든_옵션_ON_타이머_60이면_5종_플래그와_dash_t_60이_포함된다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = true
        }
        let args = SleepFlag.arguments(from: prefs, timerSeconds: 60)
        // SleepFlag.allCases 순서를 따라 -d -i -m -s -u 순으로 추가됨
        XCTAssertEqual(args, ["-d", "-i", "-m", "-s", "-u", "-t", "60"])
    }

    // MARK: - isToggleEnabled(for:isActive:timerSeconds:)

    func test_isToggleEnabled_user_비활성_무제한이면_true() {
        // 비활성 상태에서는 사용자가 미리 -u를 ON으로 설정해 둘 수 있어야 한다.
        // 무제한 시작 시 SleepFlag.arguments가 자동으로 -u를 제외하므로 부작용이 없다
        XCTAssertTrue(SleepFlag.isToggleEnabled(for: .user, isActive: false, timerSeconds: 0))
    }

    func test_isToggleEnabled_user_비활성_타이머있음이면_true() {
        XCTAssertTrue(SleepFlag.isToggleEnabled(for: .user, isActive: false, timerSeconds: 300))
    }

    func test_isToggleEnabled_user_활성_무제한이면_false() {
        // 잠가야 하는 유일한 케이스. -u는 -t 없이는 동작하지 않으므로 활성 + 무제한에서는
        // 토글을 켜도 caffeinate 프로세스에 전달되지 않아 사용자에게 혼란만 준다
        XCTAssertFalse(SleepFlag.isToggleEnabled(for: .user, isActive: true, timerSeconds: 0))
    }

    func test_isToggleEnabled_user_활성_타이머있음이면_true() {
        XCTAssertTrue(SleepFlag.isToggleEnabled(for: .user, isActive: true, timerSeconds: 300))
    }

    func test_isToggleEnabled_비_isTimerOnly_플래그는_상태와_무관하게_항상_true() {
        let nonTimerOnly: [SleepFlag] = [.display, .idle, .disk, .ac]
        // (isActive, timerSeconds) 4개 조합 전수 검사
        let cases: [(Bool, Int)] = [
            (false, 0),
            (false, 300),
            (true, 0),
            (true, 300)
        ]
        for flag in nonTimerOnly {
            for (isActive, seconds) in cases {
                XCTAssertTrue(
                    SleepFlag.isToggleEnabled(for: flag, isActive: isActive, timerSeconds: seconds),
                    "flag=\(flag) isActive=\(isActive) seconds=\(seconds)"
                )
            }
        }
    }

    @MainActor
    func test_타이머_0_또는_음수는_무제한으로_취급된다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.idle] = true
        prefs[.user] = true

        let zeroArgs = SleepFlag.arguments(from: prefs, timerSeconds: 0)
        XCTAssertFalse(zeroArgs.contains("-t"))
        XCTAssertFalse(zeroArgs.contains("-u"))
        XCTAssertEqual(zeroArgs, ["-i"])

        let negativeArgs = SleepFlag.arguments(from: prefs, timerSeconds: -1)
        XCTAssertFalse(negativeArgs.contains("-t"))
        XCTAssertFalse(negativeArgs.contains("-u"))
        XCTAssertEqual(negativeArgs, ["-i"])
    }
}
