//
//  MockCaffeinateRunner.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
@testable import caffeine

/// caffeinate 자식 프로세스 spawn을 흉내내는 테스트용 runner
///
/// `CaffeinateManager`의 상태 머신과 인자 변환 로직을 검증할 때 실제 `/usr/bin/caffeinate`를
/// 띄우지 않고 호출만 캡처한다. 종료 시뮬레이션은 `simulateTermination()`으로 수동 트리거한다
@MainActor
final class MockCaffeinateRunner: CaffeinateProcessRunner {

    /// 가장 최근 `run(arguments:onTermination:)`에 전달된 인자 배열
    private(set) var capturedArguments: [String] = []

    /// `run`이 호출된 누적 횟수
    private(set) var runCallCount: Int = 0

    /// `run`이 던질 에러. 설정되어 있으면 호출 시 해당 에러를 throw한다
    var shouldThrowOnRun: Error?

    /// 종료 콜백을 저장해 두고 테스트가 임의 시점에 호출할 수 있게 한다
    private var onTerminationHandlers: [() -> Void] = []

    /// 가장 최근에 반환한 핸들. 테스트가 직접 종료/상태 조회에 사용할 수 있다
    private(set) var lastHandle: MockCaffeinateHandle?

    func run(
        arguments: [String],
        onTermination: @escaping @Sendable () -> Void
    ) throws -> CaffeinateProcessHandle {
        runCallCount += 1
        if let error = shouldThrowOnRun {
            throw error
        }
        capturedArguments = arguments
        onTerminationHandlers.append(onTermination)
        let handle = MockCaffeinateHandle()
        lastHandle = handle
        return handle
    }

    /// caffeinate 자식이 자연 종료된 상황을 시뮬레이션한다
    ///
    /// 가장 최근 등록된 종료 콜백을 호출한다. 콜백 자체는 main isolation hop을 내부적으로
    /// 처리하므로 테스트도 hop 없이 호출하면 된다
    func simulateTermination() {
        guard let handler = onTerminationHandlers.popLast() else { return }
        handler()
    }
}

/// 종료 요청만 기록하는 테스트용 핸들
final class MockCaffeinateHandle: CaffeinateProcessHandle, @unchecked Sendable {

    private let lock = NSLock()
    private var terminated = false

    func terminate() {
        lock.lock()
        defer { lock.unlock() }
        terminated = true
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !terminated
    }

    /// 테스트 검증용. terminate()가 호출됐는지 여부
    var didTerminate: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminated
    }
}
