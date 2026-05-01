//
//  LoginItemManager.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
import Observation
import os.log

/// 로그인 시 자동 시작을 관리하는 래퍼
///
/// macOS 14+의 SMAppService.mainApp을 기본으로 사용하며 호출은 `LoginItemService` 프로토콜로
/// 추상화되어 있다. 단위 테스트에서는 in-memory mock service를 주입해 시스템 등록 부수 효과 없이
/// 토글/refresh 동작을 검증할 수 있다.
///
/// 1.0.1에서 ObservableObject + @Published를 `@Observable` 매크로로 마이그레이션했다.
/// 뷰는 `@Environment(LoginItemManager.self)`로 받는다
@MainActor
@Observable
final class LoginItemManager {

    @ObservationIgnored
    private static let logger = Logger(subsystem: "io.binaryloader.caffeine", category: "LoginItemManager")

    private(set) var isEnabled: Bool

    /// 마지막 등록/해제 시도에서 발생한 에러 메시지(없으면 nil)
    ///
    /// 사용자가 시스템 설정에서 권한 차단을 한 경우 등 등록/해제가 실패하면 이 값으로 표시한다.
    /// UI는 nil이 아닐 때 보조 안내 텍스트를 보여 다음 단계(시스템 설정 열기)를 안내한다
    private(set) var lastError: String?

    @ObservationIgnored
    private let service: LoginItemService

    init(service: LoginItemService = SystemLoginItemService()) {
        self.service = service
        self.isEnabled = service.isRegistered
    }

    /// 등록 상태를 토글한다. 실패하면 isEnabled를 시스템이 보고하는 실제 상태로 동기화한다
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if !service.isRegistered {
                    try service.register()
                }
            } else {
                if service.isRegistered {
                    try service.unregister()
                }
            }
            isEnabled = service.isRegistered
            lastError = nil
        } catch {
            // 실패 시 시스템이 보고하는 실제 상태로 동기화하고 사용자에게 표시할 에러 메시지를 저장
            Self.logger.error("LoginItem toggle failed: \(error.localizedDescription, privacy: .public)")
            isEnabled = service.isRegistered
            lastError = error.localizedDescription
        }
    }

    /// 외부 변경(시스템 설정에서 사용자가 직접 끔 등)에 동기화하기 위한 새로고침
    func refresh() {
        isEnabled = service.isRegistered
    }
}
