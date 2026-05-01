//
//  PanelController.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit
import os.log
import SwiftUI

/// 자체 NSPanel(borderless / nonactivating) 라이프사이클 + hosting view 소유 + present/dismiss를
/// 책임지는 컨트롤러
///
/// NSMenu + NSMenuItem.view 구조는 옵션 패널 펼침처럼 SwiftUI 콘텐츠가 동적으로 사이즈를 키울 때
/// NSMenuItem 사이즈를 다시 측정하지 않아 콘텐츠가 잘리는 문제가 있었다. 그래서 자체 NSPanel을
/// 띄우고 외부 클릭/ESC 키 dismiss 모니터를 직접 관리한다
///
/// AppKit `NSView`의 기본 좌표계는 y-up이라 `NSHostingView`의 intrinsic 높이가 NSPanel
/// `contentView`의 높이보다 클 때 호스팅 뷰의 하단이 contentView 바닥에 정렬되고 상단(헤더)이
/// 위로 밀려 잘리는 사례가 있었다. 이를 막기 위해 contentView를 `FlippedContainerView`로 두고
/// 그 위에 `PanelHostingView`를 자식으로 배치한다. flipped 좌표계에서는 `origin.y = 0`이 상단을
/// 의미하므로 호스팅 뷰는 항상 contentView 상단에 anchor 된다. 패널보다 콘텐츠가 크면 하단이 잘리며
/// 헤더는 항상 보인다
///
/// NSPanel 자동 리사이즈 사이클과 강한 오버슛 spring이 충돌해 무한 재귀를 일으킨 사례가 과거에
/// 있었으나 현재 구현은 약한 spring(`response: 0.22`, `dampingFraction: 0.85`)으로 바뀌어 있어
/// 충돌 위험이 없다. 콘텐츠 사이즈 변화는 `PanelHostingView`가 콜백으로 알려주고
/// `applyFrame(for:panel:)`이 화면 가용 영역으로 height를 클램프해 panel.setFrame으로 반영한다
@MainActor
final class PanelController {

    private static let logger = Logger(subsystem: "io.binaryloader.caffeine", category: "PanelController")

    private var panel: KeyablePanel?
    private var hostingView: PanelHostingView<MenuBarRootView>?
    private var flippedContainer: FlippedContainerView?

    private let frameCalculator: PanelFrameCalculator
    private let eventMonitor: PanelEventMonitor
    private let rootViewBuilder: () -> MenuBarRootView

    /// 패널 표시 직전 호출되는 훅. LoginItemManager.refresh() 등을 트리거할 때 사용한다
    var willPresent: (() -> Void)?

    /// `applyFrame` 진입 중에 콘텐츠 사이즈 콜백이 재진입하는 것을 막기 위한 가드.
    ///
    /// `panel.setFrame` 호출이 NSHostingView의 layout을 다시 트리거하고, 그 layout이
    /// 다시 onContentSizeChange를 호출하면 같은 runloop 안에서 재귀가 발생할 수 있다.
    /// 동일 사이즈 가드(`PanelHostingView.lastReportedSize`)와 frame 동일성 가드가 합쳐지면
    /// 정상 케이스에서는 무한 루프로 가지 않지만, 콘텐츠 사이즈가 진동하는 엣지 케이스에서는
    /// 한 번의 적용 사이클이 끝나기 전에 다음 콜백이 들어와 oscillation을 만들 수 있다.
    /// 이 플래그가 set인 동안에는 콜백을 무시해 한 사이클을 atomically 완료시킨다
    private var isApplyingPanelFrame: Bool = false

    init(
        rootViewBuilder: @escaping () -> MenuBarRootView,
        frameCalculator: PanelFrameCalculator,
        eventMonitor: PanelEventMonitor
    ) {
        self.rootViewBuilder = rootViewBuilder
        self.frameCalculator = frameCalculator
        self.eventMonitor = eventMonitor
    }

    /// 외부에서 PanelEventMonitor가 패널 윈도우를 조회할 때 사용한다
    var panelWindow: NSWindow? { panel }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(under statusItem: NSStatusItem) {
        if isVisible {
            dismiss()
        } else {
            present(under: statusItem)
        }
    }

    /// 패널을 생성(최초 1회)하고 statusItem 아래 위치에 표시한다
    func present(under statusItem: NSStatusItem) {
        willPresent?()

        let panel = panel ?? makePanel()
        self.panel = panel

        // 최초 표시 시점에 hosting view layout을 강제해 fittingSize를 안정화한다
        hostingView?.layoutSubtreeIfNeeded()
        let initialSize = hostingView?.fittingSize ?? panel.frame.size
        applyFrame(for: initialSize, panel: panel, statusItem: statusItem)

        // makeKeyAndOrderFront는 패널을 key window로 만들어 SwiftUI TextField가 first responder를
        // 받을 수 있게 한다. .nonactivatingPanel이라 NSApp 자체는 활성화되지 않으므로 메뉴바 앱의
        // 표준 동작(다른 앱 포커스를 뺏지 않음)은 유지된다. NSApp.activate(...)는 호출하지 않는다
        panel.makeKeyAndOrderFront(nil)

        eventMonitor.install()
    }

    func dismiss() {
        panel?.orderOut(nil)
        eventMonitor.remove()
    }

    /// 앱 종료 시 호출. 콜백/모니터/패널을 모두 해제한다
    func cleanup() {
        eventMonitor.remove()

        // 호스팅 뷰의 클로저가 self를 강하게 잡고 있을 가능성을 차단한다
        hostingView?.onContentSizeChange = nil

        panel?.close()
        panel = nil
        hostingView = nil
        flippedContainer = nil
    }

    // MARK: - Private

    /// NSPanel을 borderless / nonactivating / fullSizeContentView로 만든다
    ///
    /// borderless로 두지 않으면 macOS 기본 윈도우 chrome이 글래스 패널 모서리 너머로 보인다
    /// nonactivating은 메뉴바 앱이 패널 표시 중에도 주 앱이 되지 않도록 한다
    private func makePanel() -> KeyablePanel {
        let rootView = rootViewBuilder()

        // 콘텐츠 사이즈 변경을 감지해 NSPanel을 자동 리사이즈하는 NSHostingView 서브클래스
        let hosting = PanelHostingView<MenuBarRootView>(rootView: rootView)
        // contentView를 flipped 컨테이너로 두고 호스팅 뷰는 그 위에 수동 frame으로 배치한다.
        // Auto Layout을 끄지 않으면 NSHostingView 자체가 superview를 가득 채우려 들어
        // 상단 anchor가 깨질 수 있다
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = []
        self.hostingView = hosting

        let initialSize = hosting.fittingSize
        let contentWidth = max(initialSize.width, DesignTokens.Layout.windowWidth)
        let contentHeight = max(initialSize.height, 1)
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: contentHeight
        )

        let panel = KeyablePanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // 글래스 패널을 그대로 보여주기 위해 시스템 chrome/그림자/배경을 모두 제거한다
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        // setFrame이 OS의 기본 페이드/슬라이드 애니메이션을 타지 않도록 강제한다.
        // 콘텐츠가 줄어들 때 패널 외곽이 살짝 잔상으로 남아 상단이 흔들려 보이는 회귀를 방지한다
        panel.animationBehavior = .none
        // 패널은 항상 다크. NSColor dynamic 컬러까지 다크로 통일하기 위한 NSAppearance 강제이다
        // (다크 강제 근거 단일 주석은 `MenuBarContentView.panelBackground` 참조)
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        // first responder를 받아 ESC/탭 등 키 이벤트가 패널로 전달되게 한다
        panel.becomesKeyOnlyIfNeeded = false

        // flipped 컨테이너를 contentView로 사용한다.
        // - contentView는 fittingSize와 무관하게 패널 사이즈를 그대로 채운다
        // - 호스팅 뷰는 fittingSize.height 그대로 두어 패널보다 클 경우 하단이 잘리고 헤더는 보이게 한다
        let container = FlippedContainerView(frame: contentRect)
        container.autoresizesSubviews = false
        container.addSubview(hosting)
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: contentHeight
        )
        self.flippedContainer = container

        panel.contentView = container

        // 콘텐츠 사이즈가 변경되면 가용 영역에 맞춰 패널 frame을 다시 계산한다
        hosting.onContentSizeChange = { [weak self, weak panel, weak hosting] _ in
            guard
                let self,
                let panel,
                let hosting
            else { return }

            // 콜백 시점의 사이즈를 그대로 쓰면 SwiftUI 다중 layout pass가 끝나기 전 값일 수 있으므로
            // subtree layout을 한 번 더 강제해 안정화된 fittingSize를 측정한다
            hosting.layoutSubtreeIfNeeded()
            let stableSize = hosting.fittingSize
            // statusItem은 외부 컨트롤러가 보유하므로 콜백 경로에서는 알 수 없다.
            // 패널이 이미 표시 중일 때만 frame 갱신이 의미가 있고, 그 시점에는 statusItem이
            // 호출자(StatusItemController)에 살아있으므로 호출 측이 한 번 주입한 statusItem 참조를
            // 캡처한다. 여기서는 panel.fittingSize 안정값으로 setFrame만 갱신한다
            self.applyFrame(for: stableSize, panel: panel, statusItem: nil)
        }

        return panel
    }

    /// 콘텐츠 fittingSize를 받아 패널 frame을 계산하고 적용한다
    ///
    /// statusItem이 nil인 경로(콘텐츠 사이즈 콜백)에서는 마지막에 캐시된 statusItem을 사용한다.
    /// 첫 호출(`present` 경로)에서 statusItem을 받아 `lastStatusItem`에 저장한다
    private func applyFrame(for fittingSize: NSSize, panel: NSPanel, statusItem: NSStatusItem?) {
        // 재진입 가드. 한 사이클이 끝나기 전 동일/비동일 콜백은 모두 무시
        guard !isApplyingPanelFrame else { return }
        isApplyingPanelFrame = true
        defer { isApplyingPanelFrame = false }

        if let statusItem {
            self.lastStatusItem = statusItem
        }

        guard
            let activeStatusItem = statusItem ?? lastStatusItem,
            let button = activeStatusItem.button
        else { return }

        guard
            let calculated = frameCalculator.calculate(
                fittingSize: fittingSize,
                statusItemButton: button
            )
        else { return }

        // 호스팅 뷰는 fittingSize 그대로 둔다. flipped 컨테이너 위에 상단(y = 0) 정렬되어
        // 패널이 콘텐츠보다 작아도 헤더가 잘리지 않고 하단만 잘린다
        if let hosting = hostingView, hosting.frame != calculated.hostingFrame {
            hosting.frame = calculated.hostingFrame
        }

        // 동일 frame이면 setFrame 호출 생략(NSPanel 리사이즈 루프 방지)
        guard panel.frame != calculated.panelFrame else { return }

        panel.setFrame(calculated.panelFrame, display: true, animate: false)
        // 같은 runloop 안에서 즉시 redraw를 강제한다. 콘텐츠가 줄어드는 흐름에서 새 frame 적용과
        // 화면 반영 사이에 한 프레임 간극이 생기면 상단에 빈 글래스가 잠깐 보이는 잔상이 발생한다
        panel.displayIfNeeded()
        // 그림자는 frame 변경에 자동 추적되지만 borderless + clear 배경 조합에서 이전 그림자 외곽이
        // 잠깐 잔상으로 남는 사례가 있어 명시적으로 무효화해 새 frame 기준으로 다시 계산하게 한다
        panel.invalidateShadow()

        // 호스팅 뷰는 항상 contentView(flipped) 상단(y = 0)에 anchor 되어 있어야 한다.
        // Release 빌드에서 assert는 무력화되므로 회귀가 발생해도 사용자에게 그대로 노출된다.
        // 자가 치유 패턴으로 origin을 강제 재설정하고 회귀 신호는 Logger.warning으로 기록한다
        if let hosting = hostingView, hosting.frame.origin != .zero {
            Self.logger.warning(
                "PanelHostingView origin drifted from .zero (was \(hosting.frame.origin.debugDescription, privacy: .public)) - resetting"
            )
            hosting.frame.origin = .zero
        }
    }

    /// 콘텐츠 사이즈 콜백 경로에서 statusItem 참조를 잃지 않기 위한 캐시.
    /// `present`에서 한 번 받은 statusItem을 보관하고 콜백에서는 캐시된 값을 사용한다
    private weak var lastStatusItem: NSStatusItem?
}
