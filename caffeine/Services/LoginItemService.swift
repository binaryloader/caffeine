//
//  LoginItemService.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
import ServiceManagement

/// 로그인 시 자동 시작 서비스 추상화
///
/// `LoginItemManager`가 `SMAppService.mainApp`을 직접 호출하던 코드를 분리한다. 단위 테스트에서는
/// in-memory mock으로 교체해 실제 시스템 등록 없이 매니저의 토글/refresh 흐름을 검증할 수 있다.
///
/// `register()`/`unregister()`는 SMAppService가 메인 큐 호출을 가정하므로 `@MainActor`에서만 호출한다.
/// 프로토콜 자체에 격리를 부여해 호출 측이 격리를 잊고 백그라운드에서 호출하지 못하도록 한다
@MainActor
protocol LoginItemService {

    /// 현재 등록되어 있는지 여부. 시스템 설정에서 사용자가 직접 켜고 끈 변화도 반영된다
    var isRegistered: Bool { get }

    /// 로그인 항목으로 등록한다. 권한 거부, 시스템 설정 차단 등으로 실패하면 throw한다
    func register() throws

    /// 로그인 항목 등록을 해제한다. 이미 등록되어 있지 않다면 throw 또는 no-op이며 호출 측에서
    /// `isRegistered`로 최종 상태를 동기화한다
    func unregister() throws
}

/// `SMAppService.mainApp`을 그대로 위임하는 기본 구현
///
/// init은 의도적으로 `nonisolated`로 둔다. `LoginItemService`가 `@MainActor` 격리되어 있어 conformance
/// 클래스도 자동으로 메인 액터로 추론되는데, 그 결과 기본 init까지 메인 액터 격리되어 호출 측이
/// `LoginItemManager(service: SystemLoginItemService())`를 default 인자 형태로 쓸 수 없게 된다
/// (AppDelegate의 stored property initializer는 self 생성 이전 컨텍스트라 격리 보장이 없다).
/// init은 상태가 없으므로 nonisolated로 두어도 안전하다
final class SystemLoginItemService: LoginItemService {

    nonisolated init() {}

    var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
