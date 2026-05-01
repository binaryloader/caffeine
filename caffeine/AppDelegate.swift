//
//  AppDelegate.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit

/// 메뉴바 진입점이자 컴포지션 루트
///
/// 도메인 매니저 3종(`CaffeinateManager`, `Preferences`, `LoginItemManager`)과 인프라 컨트롤러
/// 2종(`StatusItemController`, `PanelController`)을 인스턴스화하고 서로 연결한다.
/// 패널 라이프사이클/이벤트 모니터/frame 계산/hosting view 생성은 각 컨트롤러가 담당한다
///
/// 컴포지션 루트로서의 책임은 아래 세 가지로 좁아진다
/// - 도메인 매니저 인스턴스 생성(시스템 의존성 기본값으로 단위 테스트 시 mock 주입 가능)
/// - 인프라 컨트롤러 인스턴스 생성 + 콜백/프로바이더 와이어링
/// - 앱 종료 시 정리(stop/cleanup)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 도메인

    // 컴포지션 루트. 매니저 3종을 시스템 의존성 기본값으로 생성한다.
    // - CaffeinateManager → SystemCaffeinateRunner(`/usr/bin/caffeinate` spawn) + SystemClock
    // - Preferences → UserDefaults.standard 영속화
    // - LoginItemManager → SystemLoginItemService(SMAppService.mainApp 위임)
    // 단위 테스트는 매니저를 직접 인스턴스화하며 mock runner/store/service/clock을 주입해 검증한다
    private let manager = CaffeinateManager()
    private let preferences = Preferences()
    private let loginItem = LoginItemManager()

    // MARK: - 인프라

    private var statusItemController: StatusItemController?
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frameCalculator = PanelFrameCalculator.standard
        let eventMonitor = PanelEventMonitor()

        let panelController = PanelController(
            rootViewBuilder: { [manager, preferences, loginItem] in
                MenuBarRootView(
                    manager: manager,
                    preferences: preferences,
                    loginItem: loginItem
                )
            },
            frameCalculator: frameCalculator,
            eventMonitor: eventMonitor
        )
        // 사용자가 시스템 설정에서 직접 자동 시작을 끈 경우 등 외부 변경을 패널 표시 시점에 동기화한다.
        // OptionsSection.LoginItemRow의 onAppear도 같은 호출을 하지만 패널 자체가 닫혀 있을 때
        // 발생한 변경을 감지하려면 표시 시점에도 한 번 더 트리거할 필요가 있다
        panelController.willPresent = { [loginItem] in
            loginItem.refresh()
        }
        self.panelController = panelController

        // statusItem 컨트롤러는 매니저 현재 값으로 초기화 후 `onActiveChange` 콜백을 통해
        // 이후 변화를 받는다. 1.0.0에서는 `manager.$isActive` Combine publisher를 받았지만
        // 1.0.1의 `@Observable` 마이그레이션으로 publisher가 사라져 명시적 콜백으로 대체했다
        let statusItemController = StatusItemController(initialIsActive: manager.isActive)
        statusItemController.onClick = { [weak self] in
            guard
                let self,
                let panelController = self.panelController,
                let statusItemController = self.statusItemController
            else { return }
            panelController.toggle(under: statusItemController.statusItem)
        }
        self.statusItemController = statusItemController

        manager.onActiveChange = { [weak statusItemController] isActive in
            statusItemController?.update(isActive: isActive)
        }

        // PanelEventMonitor의 외부 클릭 가드 콜백을 컨트롤러 양쪽에 연결한다.
        // - statusItemButtonWindowProvider: 메뉴바 버튼 윈도우(글로벌/로컬 모두 가드 대상)
        // - panelProvider: 현재 표시 중인 패널 윈도우(로컬 가드에서 panel 내부 클릭 제외용)
        // - onDismiss: 가드 통과한 외부 클릭/ESC 키 발생 시 호출되는 dismiss 콜백
        eventMonitor.statusItemButtonWindowProvider = { [weak statusItemController] in
            statusItemController?.statusItem.button?.window
        }
        eventMonitor.panelProvider = { [weak panelController] in
            panelController?.panelWindow
        }
        eventMonitor.onDismiss = { [weak panelController] in
            panelController?.dismiss()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stop()
        panelController?.cleanup()
        statusItemController?.cleanup()
    }
}
