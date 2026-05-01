//
//  MockLoginItemService.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
@testable import caffeine

/// 로그인 항목 서비스를 흉내내는 테스트용 구현
///
/// `LoginItemManager`의 토글/refresh/에러 동기화 동작을 검증할 때 실제 SMAppService 호출 없이
/// 등록 상태 머신만 인메모리로 유지한다. register/unregister 시 미리 설정한 에러를 throw해
/// 매니저의 에러 분기도 검증할 수 있다
@MainActor
final class MockLoginItemService: LoginItemService {

    var isRegistered: Bool = false

    /// `register()`가 던질 에러. nil이면 정상 등록한다
    var registerError: Error?

    /// `unregister()`가 던질 에러. nil이면 정상 해제한다
    var unregisterError: Error?

    private(set) var registerCallCount: Int = 0
    private(set) var unregisterCallCount: Int = 0

    func register() throws {
        registerCallCount += 1
        if let error = registerError {
            throw error
        }
        isRegistered = true
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let error = unregisterError {
            throw error
        }
        isRegistered = false
    }
}
