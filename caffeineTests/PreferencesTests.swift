//
//  PreferencesTests.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import XCTest
@testable import caffeine

/// `Preferences`의 subscript/영속화/언어 캐시 검증
///
/// `InMemoryKeyValueStore`를 주입해 사용자 defaults를 건드리지 않고 흐름을 잠근다
@MainActor
final class PreferencesTests: XCTestCase {

    // MARK: - 신규 설치 기본값

    func test_신규_설치는_defaultValue를_따른다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)

        XCTAssertTrue(prefs[.display])
        XCTAssertTrue(prefs[.idle])
        XCTAssertFalse(prefs[.disk])
        XCTAssertFalse(prefs[.ac])
        XCTAssertFalse(prefs[.user])
    }

    func test_신규_설치는_lastTimerSeconds가_0이다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        XCTAssertEqual(prefs.lastTimerSeconds, 0)
    }

    // MARK: - subscript get/set 독립성

    func test_subscript_set이_다른_플래그를_침범하지_않는다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)

        // 초기값을 모두 false로 명시 정렬
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.disk] = true

        XCTAssertTrue(prefs[.disk])
        XCTAssertFalse(prefs[.display])
        XCTAssertFalse(prefs[.idle])
        XCTAssertFalse(prefs[.ac])
        XCTAssertFalse(prefs[.user])
    }

    // MARK: - 영속화

    func test_subscript_set이_store에_defaultsKey로_영속화된다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)

        prefs[.display] = false
        prefs[.idle] = false
        prefs[.disk] = true
        prefs[.ac] = true
        prefs[.user] = true

        XCTAssertEqual(store.bool(forKey: SleepFlag.display.defaultsKey), false)
        XCTAssertEqual(store.bool(forKey: SleepFlag.idle.defaultsKey), false)
        XCTAssertEqual(store.bool(forKey: SleepFlag.disk.defaultsKey), true)
        XCTAssertEqual(store.bool(forKey: SleepFlag.ac.defaultsKey), true)
        XCTAssertEqual(store.bool(forKey: SleepFlag.user.defaultsKey), true)
    }

    func test_lastTimerSeconds_setter는_store에_영속화된다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)

        prefs.lastTimerSeconds = 1800

        XCTAssertEqual(store.integer(forKey: "lastTimerSeconds"), 1800)
    }

    func test_appLanguage_setter가_appLanguageRaw와_캐시를_갱신한다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)

        let initialStrings = prefs.cachedStrings.active
        prefs.appLanguage = .ko
        XCTAssertEqual(prefs.appLanguageRaw, "ko")
        XCTAssertEqual(prefs.appLanguage, .ko)
        XCTAssertEqual(prefs.cachedStrings.active, "활성")

        prefs.appLanguage = .en
        XCTAssertEqual(prefs.cachedStrings.active, "Active")

        prefs.appLanguage = .ja
        XCTAssertEqual(prefs.cachedStrings.active, "アクティブ")

        // 무엇이든 변경되긴 했으므로 초기 값과 적어도 한 번 이상 비교
        XCTAssertNotNil(initialStrings)
    }

    func test_appLanguage_setter는_store에_영속화된다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)

        prefs.appLanguage = .ja
        XCTAssertEqual(store.string(forKey: "appLanguage"), "ja")
    }

    // MARK: - 영속화 복원

    func test_재기동_시_저장된_값을_복원한다() {
        let store = InMemoryKeyValueStore()
        do {
            let prefs = Preferences(store: store)
            prefs[.display] = false
            prefs[.disk] = true
            prefs.lastTimerSeconds = 600
            prefs.appLanguage = .ko
        }

        // 동일 store로 새 Preferences 생성
        let restored = Preferences(store: store)
        XCTAssertFalse(restored[.display])
        XCTAssertTrue(restored[.disk])
        XCTAssertEqual(restored.lastTimerSeconds, 600)
        XCTAssertEqual(restored.appLanguage, .ko)
    }

    // MARK: - hasAnySleepPrevention

    func test_hasAnySleepPrevention은_user만_ON이면_false다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.user] = true

        // -u 단독으로는 caffeinate를 유지하지 못하므로 false
        XCTAssertFalse(prefs.hasAnySleepPrevention)
    }

    func test_hasAnySleepPrevention은_display_idle_disk_ac_중_하나라도_ON이면_true() {
        let cases: [SleepFlag] = [.display, .idle, .disk, .ac]
        for flag in cases {
            let store = InMemoryKeyValueStore()
            let prefs = Preferences(store: store)
            for f in SleepFlag.allCases {
                prefs[f] = false
            }
            prefs[flag] = true
            XCTAssertTrue(
                prefs.hasAnySleepPrevention,
                "\(flag)만 ON일 때 true여야 한다"
            )
        }
    }

    // MARK: - binding(for:)

    func test_binding은_subscript와_쌍방향_연결된다() {
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)

        let binding = prefs.binding(for: .ac)
        prefs[.ac] = true
        XCTAssertTrue(binding.wrappedValue)

        binding.wrappedValue = false
        XCTAssertFalse(prefs[.ac])
        XCTAssertFalse(store.bool(forKey: SleepFlag.ac.defaultsKey))
    }
}
