//
//  Clock.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation

/// 카운트다운에 필요한 시간 의존성을 추상화한 프로토콜
///
/// `CaffeinateManager.startCountdown`은 절대 시간(`Date()`)과 비동기 sleep(`Task.sleep`) 두 가지
/// 시간 의존성을 동시에 사용한다. 단위 테스트에서 둘 다 mock으로 교체할 수 있어야 카운트다운
/// 표시값과 0초 도달 시점을 결정적으로 검증할 수 있다.
///
/// 두 메서드를 한 프로토콜에 묶은 이유는 카운트다운이 "now와 sleep을 함께 사용해 진행"하는
/// 단일 행위이기 때문이다. 테스트에서 한 쪽만 mock하면(예: now만 mock하고 sleep은 실제 대기)
/// 가속이 의미 없어지고, 반대로 sleep만 mock하면 만료 시점 계산을 실제 wall-clock에 맡겨야 해
/// 검증이 흔들린다. 묶어 두면 mock에서 둘이 일관된 가짜 시간축으로 움직인다.
///
/// `Sendable`을 강제해 매니저의 `@MainActor` 격리에서도 hop 없이 안전하게 보유할 수 있게 한다.
/// `sleep(nanoseconds:)`는 `async`이며 cancel을 지원해야 한다(`Task.sleep`과 동일한 계약).
/// cancel이 들어오면 `CancellationError`를 던지지 말고 즉시 반환만 해도 무방하도록 throws를
/// 두지 않았다. 매니저의 카운트다운 루프가 `Task.isCancelled`로 다음 루프 진입을 막기 때문이다
protocol Clock: Sendable {

    /// 현재 시각. `SystemClock`은 `Date()`을 그대로 반환한다
    func now() -> Date

    /// `nanoseconds`만큼 대기한다. 외부 cancel이 들어오면 즉시 반환해야 한다
    func sleep(nanoseconds: UInt64) async
}

/// 시스템 wall-clock을 그대로 사용하는 기본 구현
///
/// `Task.sleep`은 실패할 수 있지만 카운트다운 루프 입장에서는 cancel/실패 모두 "더 이상 sleep
/// 할 수 없다"는 같은 의미다. throw를 흡수하고 그냥 반환해 호출 측이 다음 루프 가드(`isCancelled`)
/// 한 곳에서만 처리하도록 한다
struct SystemClock: Clock {

    func now() -> Date { Date() }

    func sleep(nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}
