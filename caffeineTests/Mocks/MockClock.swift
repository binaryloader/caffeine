//
//  MockClock.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
@testable import caffeine

/// 카운트다운 검증용 결정적 mock clock
///
/// 핵심 설계
/// - `now()`는 내부 가짜 시각을 반환한다. `advance(by:)`로만 진행한다
/// - `sleep(nanoseconds:)`는 즉시 반환해 카운트다운 루프가 wall-clock 대기 없이 빠르게 도는 동시에
///   매 루프 사이에 테스트가 시간을 이동시킬 기회를 만든다. 즉시 반환 후 메인 액터 yield를 한 번
///   더 끼워 SwiftUI/매니저의 메인 액터 작업이 진행되도록 한다
/// - 동시성 안전성: `@unchecked Sendable`로 표시하고 내부 상태를 `NSLock`으로 보호한다.
///   `Sendable`을 강제하는 `Clock` 프로토콜 계약을 만족시키기 위함이다
final class MockClock: Clock, @unchecked Sendable {

    private let lock = NSLock()
    private var currentTime: Date

    init(start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.currentTime = start
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return currentTime
    }

    /// 가짜 시각을 `seconds`만큼 진행한다
    func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        currentTime = currentTime.addingTimeInterval(seconds)
    }

    /// `Clock.sleep` 구현. 즉시 반환하지만 메인 액터에 yield를 한 번 끼워 호출 측의 메인 큐
    /// 후속 작업(remainingSeconds 비교/대입 등)이 진행되도록 한다.
    ///
    /// `Task.yield()` 한 번으로는 매니저 측 카운트다운 루프 다음 사이클이 보장되지 않을 수 있어
    /// 테스트는 `expectation` + `wait(for:)` 또는 `Task.sleep(nanoseconds: 1_000_000)`로
    /// 추가 양보를 줄 수 있다. 이 mock 자체는 wall-clock을 차지하지 않는다
    func sleep(nanoseconds: UInt64) async {
        await Task.yield()
    }
}
