//
//  CaffeinateManagerTests.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import XCTest
@testable import caffeine

/// `CaffeinateManager`의 인자 변환과 상태 머신 검증
///
/// `MockCaffeinateRunner`를 주입해 실제 자식 프로세스 spawn 없이 인자/생명주기를 검증한다.
/// 카운트다운(시간 의존) 검증은 본 Phase에서는 0초 timer + 0.0초 측정 등 시간 가속이 필요
/// 없는 케이스만 잠그고, Clock 추상화가 도입되면 후속 테스트로 보강한다(보고서 본문 참고)
@MainActor
final class CaffeinateManagerTests: XCTestCase {

    // MARK: - 인자 변환

    func test_start는_dash_w_PID를_prepend하고_SleepFlag_arguments를_뒤에_붙인다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.display] = true
        prefs[.idle] = true
        prefs.lastTimerSeconds = 0

        manager.start(with: prefs)

        // -w PID + -d -i 순서
        XCTAssertGreaterThanOrEqual(runner.capturedArguments.count, 4)
        XCTAssertEqual(runner.capturedArguments[0], "-w")
        XCTAssertEqual(
            runner.capturedArguments[1],
            String(ProcessInfo.processInfo.processIdentifier)
        )
        XCTAssertTrue(runner.capturedArguments.contains("-d"))
        XCTAssertTrue(runner.capturedArguments.contains("-i"))
        XCTAssertFalse(runner.capturedArguments.contains("-t"))
    }

    func test_start는_모든_옵션_OFF에서_dash_i를_fallback으로_추가한다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs.lastTimerSeconds = 0

        manager.start(with: prefs)

        // -w PID -i 순서. SleepFlag.arguments는 빈 배열을 반환하지만 매니저가 fallback으로 -i prepend
        XCTAssertEqual(runner.capturedArguments[0], "-w")
        XCTAssertTrue(runner.capturedArguments.contains("-i"))
    }

    func test_start는_타이머와_user_조합에서_dash_u_dash_t를_포함한다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.idle] = true
        prefs[.user] = true
        prefs.lastTimerSeconds = 300

        manager.start(with: prefs)

        XCTAssertTrue(runner.capturedArguments.contains("-i"))
        XCTAssertTrue(runner.capturedArguments.contains("-u"))
        XCTAssertTrue(runner.capturedArguments.contains("-t"))
        XCTAssertTrue(runner.capturedArguments.contains("300"))
    }

    // MARK: - isActive 상태 머신

    func test_start_후_isActive는_true이고_stop_후_false가_된다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.idle] = true

        XCTAssertFalse(manager.isActive)
        manager.start(with: prefs)
        XCTAssertTrue(manager.isActive)

        manager.stop()
        XCTAssertFalse(manager.isActive)
    }

    func test_runner_종료_콜백이_호출되면_isActive가_false로_동기화된다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true

        manager.start(with: prefs)
        XCTAssertTrue(manager.isActive)

        // 자식 프로세스 자연 종료를 시뮬레이션하면 매니저가 main isolation에서 stop()을 호출해
        // isActive가 false가 되어야 한다. Task hop이 필요하므로 expectation으로 대기
        let expectation = self.expectation(
            description: "자식 종료 시 매니저가 isActive를 false로 갱신한다"
        )
        Task { @MainActor in
            runner.simulateTermination()
            // simulateTermination 내부에서 또 한 번 Task hop이 일어나므로 한 사이클 더 양보
            try? await Task.sleep(nanoseconds: 50_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(manager.isActive)
    }

    // MARK: - launch 실패 처리

    func test_runner가_throw하면_isActive는_false로_유지된다() {
        struct FakeError: Error {}

        let runner = MockCaffeinateRunner()
        runner.shouldThrowOnRun = FakeError()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true

        manager.start(with: prefs)

        // launchProcess가 catch에서 isActive=false로 둔다. 이전 isActive=true가 잠깐 set되어도
        // 메서드 종료 시점에는 false로 정리되어야 한다(매니저 코드 흐름 참고)
        // 현재 구현은 isActive=true를 launch 이후에 set하므로 throw 시 true가 set되지 않는다
        XCTAssertFalse(manager.isActive)
    }

    // MARK: - infinite 활성

    func test_activateInfinite는_lastTimerSeconds를_0으로_만들고_start한다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.idle] = true
        prefs.lastTimerSeconds = 1800

        manager.activateInfinite(with: prefs)

        XCTAssertEqual(prefs.lastTimerSeconds, 0)
        XCTAssertTrue(manager.isActive)
        XCTAssertNil(manager.remainingSeconds)
        XCTAssertFalse(runner.capturedArguments.contains("-t"))
    }

    func test_activateInfinite는_isTimerOnly_플래그를_OFF로_되돌린다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        for flag in SleepFlag.allCases {
            prefs[flag] = false
        }
        prefs[.idle] = true
        // 비활성 상태에서 사용자가 미리 -u를 ON으로 켜둔 시나리오
        prefs[.user] = true

        manager.activateInfinite(with: prefs)

        // -u는 OFF로 되돌려야 하고 비-isTimerOnly 플래그(idle)는 보존되어야 한다
        XCTAssertFalse(prefs[.user])
        XCTAssertTrue(prefs[.idle])
        // caffeinate 인자에도 -u가 포함되지 않는다
        XCTAssertFalse(runner.capturedArguments.contains("-u"))
    }

    // MARK: - 재시작

    func test_restartIfActive는_inactive면_no_op이다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true

        manager.restartIfActive(with: prefs)
        XCTAssertEqual(runner.runCallCount, 0)
        XCTAssertFalse(manager.isActive)
    }

    func test_restartIfActive는_active면_runner_run을_한_번_더_호출한다() {
        let runner = MockCaffeinateRunner()
        let manager = CaffeinateManager(runner: runner)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true

        manager.start(with: prefs)
        XCTAssertEqual(runner.runCallCount, 1)

        prefs[.disk] = true
        manager.restartIfActive(with: prefs)
        XCTAssertEqual(runner.runCallCount, 2)
        XCTAssertTrue(runner.capturedArguments.contains("-m"))
    }

    // MARK: - 카운트다운(Clock 추상화 기반 시간 가속 검증)

    /// 카운트다운 루프가 한 사이클을 진행할 수 있도록 메인 액터에 양보한다
    ///
    /// `MockClock.sleep`은 즉시 반환하지만 매니저의 카운트다운 Task가 다음 사이클을 실행하려면
    /// 메인 액터에 작은 양보가 필요하다. `Task.yield()` 한 번으로는 디스패치 큐 흐름상 부족할 수
    /// 있어 짧은 wall-clock sleep으로 양보한다(전체 테스트 wall-clock 영향은 무시 가능 수준)
    private func yieldCountdownLoop() async {
        for _ in 0 ..< 5 {
            try? await Task.sleep(nanoseconds: 1_000_000)
            await Task.yield()
        }
    }

    func test_카운트다운_시작_시_remainingSeconds가_타이머_길이로_초기화된다() {
        let runner = MockCaffeinateRunner()
        let clock = MockClock()
        let manager = CaffeinateManager(runner: runner, clock: clock)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true
        prefs.lastTimerSeconds = 300

        manager.start(with: prefs)

        XCTAssertEqual(manager.remainingSeconds, 300)
    }

    func test_카운트다운은_시간_진행에_따라_remainingSeconds를_감소시킨다() async {
        let runner = MockCaffeinateRunner()
        let clock = MockClock()
        let manager = CaffeinateManager(runner: runner, clock: clock)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true
        prefs.lastTimerSeconds = 60

        manager.start(with: prefs)
        XCTAssertEqual(manager.remainingSeconds, 60)

        // 30초 진행 후 카운트다운 루프가 한 사이클 더 돌기를 기다림
        clock.advance(by: 30)
        await yieldCountdownLoop()
        XCTAssertEqual(manager.remainingSeconds, 30)

        // 추가로 25초 진행 (총 55초 진행) - 5초 남음
        clock.advance(by: 25)
        await yieldCountdownLoop()
        XCTAssertEqual(manager.remainingSeconds, 5)
    }

    func test_카운트다운은_시간_경과로_0에_도달하면_0을_표시하고_루프를_끝낸다() async {
        let runner = MockCaffeinateRunner()
        let clock = MockClock()
        let manager = CaffeinateManager(runner: runner, clock: clock)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true
        prefs.lastTimerSeconds = 10

        manager.start(with: prefs)

        // 만료 시점 정확히 통과
        clock.advance(by: 10)
        await yieldCountdownLoop()

        XCTAssertEqual(manager.remainingSeconds, 0)
    }

    func test_stop_호출_시_remainingSeconds가_nil로_초기화된다() async {
        let runner = MockCaffeinateRunner()
        let clock = MockClock()
        let manager = CaffeinateManager(runner: runner, clock: clock)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true
        prefs.lastTimerSeconds = 120

        manager.start(with: prefs)
        XCTAssertEqual(manager.remainingSeconds, 120)

        manager.stop()
        XCTAssertNil(manager.remainingSeconds)
        XCTAssertFalse(manager.isActive)
    }

    func test_무제한_모드는_remainingSeconds를_nil로_둔다() {
        let runner = MockCaffeinateRunner()
        let clock = MockClock()
        let manager = CaffeinateManager(runner: runner, clock: clock)
        let store = InMemoryKeyValueStore()
        let prefs = Preferences(store: store)
        prefs[.idle] = true
        prefs.lastTimerSeconds = 0

        manager.start(with: prefs)

        XCTAssertTrue(manager.isActive)
        XCTAssertNil(manager.remainingSeconds)
    }
}
