//
//  LoginItemManagerTests.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import XCTest
@testable import caffeine

/// `LoginItemManager`의 토글/refresh/에러 동기화 검증
///
/// `MockLoginItemService`를 주입해 SMAppService를 호출하지 않고 매니저의 분기를 잠근다
@MainActor
final class LoginItemManagerTests: XCTestCase {

    // MARK: - 초기 동기화

    func test_init_시_service_isRegistered_상태를_isEnabled로_복사한다() {
        let service = MockLoginItemService()
        service.isRegistered = true

        let manager = LoginItemManager(service: service)

        XCTAssertTrue(manager.isEnabled)
        XCTAssertNil(manager.lastError)
    }

    // MARK: - setEnabled

    func test_setEnabled_true면_service_register를_호출한다() {
        let service = MockLoginItemService()
        service.isRegistered = false
        let manager = LoginItemManager(service: service)

        manager.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertNil(manager.lastError)
    }

    func test_setEnabled_false면_service_unregister를_호출한다() {
        let service = MockLoginItemService()
        service.isRegistered = true
        let manager = LoginItemManager(service: service)

        manager.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertNil(manager.lastError)
    }

    func test_이미_등록된_상태에서_setEnabled_true면_register를_재호출하지_않는다() {
        let service = MockLoginItemService()
        service.isRegistered = true
        let manager = LoginItemManager(service: service)

        manager.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertTrue(manager.isEnabled)
    }

    func test_이미_해제된_상태에서_setEnabled_false면_unregister를_재호출하지_않는다() {
        let service = MockLoginItemService()
        service.isRegistered = false
        let manager = LoginItemManager(service: service)

        manager.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertFalse(manager.isEnabled)
    }

    // MARK: - 에러 분기

    func test_register_실패하면_lastError를_설정하고_isEnabled를_시스템_상태로_동기화한다() {
        struct FakeError: LocalizedError {
            var errorDescription: String? { "권한 거부" }
        }
        let service = MockLoginItemService()
        service.isRegistered = false
        service.registerError = FakeError()
        let manager = LoginItemManager(service: service)

        manager.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertEqual(manager.lastError, "권한 거부")
    }

    func test_unregister_실패하면_lastError를_설정한다() {
        struct FakeError: LocalizedError {
            var errorDescription: String? { "차단됨" }
        }
        let service = MockLoginItemService()
        service.isRegistered = true
        service.unregisterError = FakeError()
        let manager = LoginItemManager(service: service)

        manager.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertEqual(manager.lastError, "차단됨")
    }

    func test_성공_후에는_lastError가_nil로_초기화된다() {
        struct FakeError: LocalizedError {
            var errorDescription: String? { "권한 거부" }
        }
        let service = MockLoginItemService()
        service.isRegistered = false
        service.registerError = FakeError()
        let manager = LoginItemManager(service: service)

        manager.setEnabled(true)
        XCTAssertEqual(manager.lastError, "권한 거부")

        // 다음 시도부터는 성공한다고 가정
        service.registerError = nil
        manager.setEnabled(true)
        XCTAssertNil(manager.lastError)
        XCTAssertTrue(manager.isEnabled)
    }

    // MARK: - refresh

    func test_refresh는_service_isRegistered와_isEnabled를_재동기화한다() {
        let service = MockLoginItemService()
        service.isRegistered = false
        let manager = LoginItemManager(service: service)
        XCTAssertFalse(manager.isEnabled)

        // 시스템 설정에서 사용자가 직접 켠 상황 시뮬레이션
        service.isRegistered = true
        manager.refresh()
        XCTAssertTrue(manager.isEnabled)

        // 반대 방향
        service.isRegistered = false
        manager.refresh()
        XCTAssertFalse(manager.isEnabled)
    }
}
