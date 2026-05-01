//
//  CaffeinateProcessRunner.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation

/// caffeinate 자식 프로세스 실행 책임을 추상화한 프로토콜
///
/// `CaffeinateManager`가 직접 `Process()`를 만들어 `/usr/bin/caffeinate`를 spawn하던 코드를 분리해
/// 단위 테스트에서 mock으로 교체할 수 있게 한다. 실제 프로덕션 구현은 `SystemCaffeinateRunner`이며
/// 테스트에서는 인자/종료 콜백을 검증하는 mock 구현을 사용한다.
///
/// `@MainActor` 격리는 호출 측(`CaffeinateManager`) 책임이며 프로토콜 자체는 격리를 강제하지 않는다.
/// `Process` 자체는 thread-safe하게 launch/terminate되도록 설계되어 있어 nonisolated 호출이 가능하지만
/// 매니저가 메인 액터에서 호출하는 흐름과 일관성을 위해 격리는 호출 측에서 결정한다
@MainActor
protocol CaffeinateProcessRunner {

    /// caffeinate 자식 프로세스를 시작한다
    ///
    /// - Parameters:
    ///   - arguments: caffeinate에 전달할 인자(`-w PID`, `-i`, `-d` 등). 매니저가 PID 워치
    ///     인자를 prepend하여 전달하며 runner는 받은 그대로 사용한다
    ///   - onTermination: 자식 프로세스가 종료됐을 때 호출되는 콜백. 임의 큐에서 호출될 수
    ///     있으므로 호출 측은 main isolation hop을 직접 처리한다
    /// - Returns: 시작된 프로세스를 제어할 수 있는 핸들
    /// - Throws: 프로세스 실행 실패 시 `Process.run()`이 던지는 에러를 그대로 전파한다
    func run(
        arguments: [String],
        onTermination: @escaping @Sendable () -> Void
    ) throws -> CaffeinateProcessHandle
}

/// 실행 중인 caffeinate 프로세스에 대한 추상 핸들
///
/// `Process`를 직접 노출하지 않고 종료 요청과 실행 여부 확인 기능만 노출해 mock 구현이
/// `Process` 라이프사이클을 흉내내지 않아도 되도록 한다.
///
/// `terminate()`는 `Process.terminate()`가 thread-safe한 것과 동일하게 격리 없이 호출 가능해야 한다
/// (`CaffeinateManager.deinit`이 nonisolated에서 호출하기 때문). `isRunning`도 동일하게 nonisolated에서
/// 안전하게 조회 가능해야 한다
protocol CaffeinateProcessHandle: Sendable {

    /// 프로세스에 SIGTERM을 보낸다. 이미 종료된 경우 no-op이어야 한다
    func terminate()

    /// 프로세스가 아직 실행 중인지 여부
    var isRunning: Bool { get }
}

/// 시스템의 `/usr/bin/caffeinate`를 실제로 실행하는 기본 구현
///
/// init은 의도적으로 `nonisolated`로 둔다. `CaffeinateProcessRunner`가 `@MainActor` 격리되어 있어
/// conformance 클래스도 메인 액터로 추론되는데, 그 결과 init까지 격리되면 호출 측이 default 인자로
/// 인스턴스를 생성하기 어려워진다(AppDelegate의 stored property initializer는 self 생성 이전
/// 컨텍스트라 격리 보장이 없다). init은 단순 값 보관이므로 nonisolated로 두어도 안전하다
final class SystemCaffeinateRunner: CaffeinateProcessRunner {

    /// caffeinate 실행 경로. 기본값은 시스템 표준 위치이며 테스트에서는 다른 경로를 주입할 수 있다
    private let executablePath: String

    nonisolated init(executablePath: String = "/usr/bin/caffeinate") {
        self.executablePath = executablePath
    }

    func run(
        arguments: [String],
        onTermination: @escaping @Sendable () -> Void
    ) throws -> CaffeinateProcessHandle {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        // 자식 프로세스가 표준 입출력을 상속하지 않도록 분리한다.
        // Pipe를 그대로 두면 caffeinate가 stdout/stderr에 무언가 쓸 때 16KB 커널 버퍼가 가득 차면
        // 자식이 write에서 블록되어 종료가 지연될 수 있다. 빈 read 핸들러를 달아 즉시 배수한다
        process.standardInput = nil
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        process.terminationHandler = { _ in
            // 종료 핸들러는 임의 큐에서 호출되므로 read 핸들러를 명시적으로 닫아 dangling을 막는다
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            onTermination()
        }

        try process.run()
        return SystemCaffeinateHandle(process: process)
    }
}

/// `Process`를 감싸는 시스템 핸들 구현
///
/// `Process`는 `Sendable`이 아니지만 우리가 사용하는 두 메서드(`terminate()`, `isRunning`)는
/// 내부적으로 thread-safe하게 동작한다. `@unchecked Sendable`로 표시해 매니저의 nonisolated deinit과
/// 종료 콜백에서 안전하게 호출하게 한다
final class SystemCaffeinateHandle: CaffeinateProcessHandle, @unchecked Sendable {

    private let process: Process

    init(process: Process) {
        self.process = process
    }

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }

    var isRunning: Bool {
        process.isRunning
    }
}
