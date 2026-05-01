//
//  CaffeinateManager.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
import Observation
import os.log
import SwiftUI

/// caffeinate(8) 자식 프로세스를 관리하는 매니저
///
/// - Process는 백그라운드 큐에서 실행하지만 상태 갱신은 모두 메인 스레드에서 처리한다
/// - 활성 상태에서 옵션이 바뀌면 호출 측에서 restart(with:)를 호출해 재시작한다
/// - 프로세스 spawn 책임은 `CaffeinateProcessRunner` 프로토콜로 분리되어 있다. 기본값은
///   `SystemCaffeinateRunner`이며 단위 테스트에서는 mock runner를 주입해 실제 자식 프로세스 없이
///   매니저의 상태 머신을 검증할 수 있다
///
/// 1.0.1에서 ObservableObject + @Published를 `@Observable` 매크로로 마이그레이션했다.
/// `@Observable`은 KVO 기반 `objectWillChange`/`@Published` Combine publisher를 자동 생성하지
/// 않으므로 `StatusItemController`가 사용하던 `manager.$isActive` 구독은 명시적 콜백
/// (`onActiveChange`)으로 대체했다. SwiftUI 뷰는 `@Environment(CaffeinateManager.self)`로
/// 받는다
@MainActor
@Observable
final class CaffeinateManager {

    /// caffeinate 실행/정리 흐름의 디버깅과 진단용 Logger
    @ObservationIgnored
    private static let logger = Logger(subsystem: "io.binaryloader.caffeine", category: "CaffeinateManager")

    private(set) var isActive: Bool = false {
        didSet {
            // @Published 시절에는 외부에서 `manager.$isActive`를 구독해 statusItem 아이콘을
            // 갱신했지만 @Observable에는 Combine publisher가 없다. 명시적 콜백으로 대체해
            // 호출 측이 옵저버를 등록할 수 있게 한다. didSet은 isActive 값이 바뀐 직후 호출되며
            // 동일 사이클에서 한 번만 발생하므로 SwiftUI의 @Observable 트래커와 중복되지 않는다
            if oldValue != isActive {
                onActiveChange?(isActive)
            }
        }
    }

    /// 활성 상태에서 남은 시간(초). 무제한 모드면 nil이다
    private(set) var remainingSeconds: Int?

    /// 활성 상태가 변할 때마다 호출되는 옵저버 콜백
    ///
    /// 메뉴바 statusItem 아이콘 갱신처럼 SwiftUI 뷰 트리 바깥의 컨슈머가 활성 상태 변화를
    /// 알아야 할 때 사용한다. SwiftUI 뷰는 그냥 `manager.isActive`를 읽으면
    /// `@Observable` 트래커가 자동으로 갱신해주므로 이 콜백을 등록할 필요가 없다.
    ///
    /// `@ObservationIgnored`로 표시해 콜백 자체가 변경 추적 대상이 되지 않게 한다
    @ObservationIgnored
    var onActiveChange: ((Bool) -> Void)?

    /// caffeinate 자식 프로세스 핸들. deinit이 nonisolated이므로 동시 접근 가능성을 표시한다
    ///
    /// 일반적인 read/write는 모두 `@MainActor` 메서드 내부에서 일어나므로 race가 발생하지 않는다.
    /// deinit에서는 `processHandle?.terminate()`만 호출하며 `terminate` 자체는 thread-safe하게
    /// 구현되도록 `CaffeinateProcessHandle` 프로토콜이 강제한다
    @ObservationIgnored
    private nonisolated(unsafe) var processHandle: CaffeinateProcessHandle?

    @ObservationIgnored
    private var endDate: Date?

    @ObservationIgnored
    private var countdownTask: Task<Void, Never>?

    /// 프로세스 spawn을 담당하는 runner. 기본값은 시스템 `/usr/bin/caffeinate`를 실제 실행한다
    @ObservationIgnored
    private let runner: CaffeinateProcessRunner

    /// 카운트다운에 사용하는 시간 의존성. 단위 테스트에서는 `MockClock`을 주입해 시간을 가속한다
    ///
    /// `Date()` 직접 호출과 `Task.sleep` 직접 호출을 매니저에서 제거하기 위한 추상화이다.
    /// 카운트다운 만료 시점/표시값 갱신은 시간 진행 가속이 가능해야만 결정적으로 검증할 수 있어
    /// 1.0.1에서 도입했다
    @ObservationIgnored
    private let clock: Clock

    init(
        runner: CaffeinateProcessRunner = SystemCaffeinateRunner(),
        clock: Clock = SystemClock()
    ) {
        self.runner = runner
        self.clock = clock
    }

    deinit {
        // deinit은 nonisolated이므로 main isolation 진입 없이 안전한 호출만 수행한다.
        // processHandle.terminate()는 nonisolated 안전 호출이며 자식이 살아 있으면 SIGTERM을 보낸다.
        // countdownTask 취소는 명시적 stop()의 책임이며 deinit에서는 시도하지 않는다(nonisolated 격리 위반)
        processHandle?.terminate()
    }

    /// caffeinate를 시작한다. 옵션이 하나도 없으면 기본으로 -i를 임시 추가해 즉시 종료를 막는다
    ///
    /// fallback 처리는 매니저 내부에서 인자 배열을 가공해 처리한다. 과거에는
    /// `preferences.preventSystemIdleSleep = true`로 사용자 설정을 mutate했지만 단방향 데이터
    /// 흐름을 깨고 사용자가 의도적으로 모두 끈 상태가 영속적으로 변경되는 부작용이 있었다.
    /// 이제 Preferences는 그대로 두고 caffeinate 인자만 임시로 보강해 토글 UI 상태와 사용자
    /// 의도를 보존한다
    func start(with preferences: Preferences) {
        // 이미 동작 중이면 재시작
        if isActive { stop() }

        let timerSeconds = preferences.lastTimerSeconds
        var arguments = SleepFlag.arguments(from: preferences, timerSeconds: timerSeconds > 0 ? timerSeconds : nil)
        // 의미 있는 sleep flag가 하나도 없으면 caffeinate가 즉시 종료된다.
        // -t는 단독으로 caffeinate를 유지하지 못하므로 -i를 prepend해 fallback으로 동작한다.
        // (-u는 isTimerOnly이므로 이미 timerSeconds 0일 때 인자에 포함되지 않는다)
        let hasSleepBlocker = SleepFlag.allCases.contains { flag in
            !flag.isTimerOnly && preferences[flag]
        }
        if !hasSleepBlocker {
            // -i를 인자 맨 앞에 두어 의미 보강. -t/타이머가 함께 있어도 -i와 공존 가능하다
            arguments.insert(SleepFlag.idle.cliArgument, at: 0)
        }
        // launchProcess는 실패 시 processHandle을 nil로 두고 끝낸다. 호출 측에서 핸들 존재 여부로
        // launch 성공을 판정해 isActive를 set한다. 과거에는 launchProcess 직후 무조건
        // `isActive = true`를 set한 뒤 launch 실패 catch가 다시 false로 되돌렸지만, 코드 순서상
        // launchProcess가 동기적으로 catch에 진입한 후에도 곧이어 `isActive = true`가 실행되어
        // 사용자에게 "활성"으로 잘못 표시되는 회귀가 있었다
        launchProcess(arguments: arguments)
        guard processHandle != nil else { return }

        isActive = true
        startCountdown(timerSeconds: timerSeconds)
    }

    /// 활성 중인 옵션 변경 시 호출하여 새 옵션으로 caffeinate를 재시작한다
    func restartIfActive(with preferences: Preferences) {
        guard isActive else { return }

        start(with: preferences)
    }

    /// 자식 프로세스를 종료하고 상태를 비활성으로 되돌린다
    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        endDate = nil
        remainingSeconds = nil

        if let handle = processHandle, handle.isRunning {
            handle.terminate()
        }
        processHandle = nil
        isActive = false
    }

    /// 헤더 메인 토글 ON 시 ∞ 모드로 활성화한다
    ///
    /// 핸드오프 명세: "메인 토글 ON" → ∞ 타이머로 활성화
    ///
    /// 무제한 진입 시점에 isTimerOnly 플래그(`-u`)를 OFF로 되돌린다. 사용자가 비활성 상태에서
    /// `-u`를 ON으로 켜둔 채 메인 토글로 무제한 모드를 시작하면 토글은 disable로 잠기지만
    /// 시각적으로 ON으로 남아 "켜놨는데 잠겼다 = 동작하는 줄 알았는데 안 한다"는 잘못된 인상을 준다.
    /// `start(with:)`는 단방향 흐름 보존을 위해 preferences를 mutate하지 않지만, `activateInfinite`는
    /// "무제한으로 시작"이라는 사용자 의도가 액션 자체에 담겨 있으므로 같은 사이클에서 의도와
    /// 같은 방향으로 mutate하는 것이 합리적이다(옵션 토글이 OFF인데 매니저가 ON으로 되돌리는 식의
    /// 단방향 위반 사례와는 다르다)
    func activateInfinite(with preferences: Preferences) {
        preferences.lastTimerSeconds = 0
        preferences.disableTimerOnlyFlags()
        start(with: preferences)
    }

    private func launchProcess(arguments: [String]) {
        // -w PID는 caffeinate가 부모 PID를 감시하다가 부모가 죽으면 자동으로 종료되게 한다.
        // 사용자가 앱을 강제 종료하거나 크래시해도 sleep assertion이 시스템에 잔존하지 않는다.
        // 명시 인자(-d/-i 등)보다 앞에 두어 의미상 prepend한다
        let pid = ProcessInfo.processInfo.processIdentifier
        let watchedArguments = ["-w", String(pid)] + arguments

        do {
            // 종료 콜백은 임의 큐에서 호출되므로 main isolation으로 hop한 뒤 상태를 정리한다.
            // 사용자가 stop()을 먼저 호출했다면 isActive가 이미 false이므로 무시한다
            let handle = try runner.run(arguments: watchedArguments) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if self.isActive {
                        self.stop()
                    }
                }
            }
            self.processHandle = handle
        } catch {
            // 실행 실패 시 활성 상태로 만들지 않는다
            Self.logger.error("caffeinate launch failed: \(error.localizedDescription, privacy: .public)")
            self.processHandle = nil
            self.isActive = false
        }
    }

    private func startCountdown(timerSeconds: Int) {
        countdownTask?.cancel()
        guard timerSeconds > 0 else {
            endDate = nil
            remainingSeconds = nil
            return
        }

        let end = clock.now().addingTimeInterval(TimeInterval(timerSeconds))
        endDate = end
        remainingSeconds = timerSeconds

        // 0.5초 polling 주기로 sub-second jitter를 흡수한다.
        // 1초 polling은 Task.sleep 정확도/메인 큐 점유 등 영향으로 같은 초가 두 번 표시되거나
        // 한 초 건너뛰는 시각적 흔들림을 만들 수 있다. 표시값(`remainingSeconds`)은 항상
        // `endDate` 절대 시간 기준의 ceiling으로 계산하므로 drift 자체는 발생하지 않으며,
        // 실제 표시값이 바뀐 경우에만 트래커를 깨워 불필요한 SwiftUI 재평가를 피한다.
        // 시간 의존성은 `clock`을 통해 주입되며 테스트에서는 `MockClock`이 즉시 반환한다
        let clock = self.clock
        countdownTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard
                    let self,
                    let endDate = self.endDate
                else { return }

                let remaining = endDate.timeIntervalSince(clock.now())
                let displaySeconds = max(0, Int(remaining.rounded(.up)))
                if self.remainingSeconds != displaySeconds {
                    self.remainingSeconds = displaySeconds
                }
                if displaySeconds <= 0 { return }

                await clock.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}
