//
//  PanelEventMonitor.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit

/// 패널 표시 중 외부 클릭/ESC를 감지하기 위한 NSEvent 모니터 묶음
///
/// 글로벌/로컬 마우스 모니터와 ESC 키 모니터를 함께 관리한다. 콜백/프로바이더 패턴은 컨트롤러 간
/// 강결합을 피하기 위한 선택이다. delegate 프로토콜을 도입하면 PanelController/StatusItemController
/// 양쪽이 PanelEventMonitorDelegate를 구현해야 해서 표면적이 늘고, 모니터가 콜백 시점에 어떤
/// 윈도우를 비교 대상으로 삼는지가 코드 외부에서는 보이지 않는 단점이 있다. 클로저 프로바이더는
/// 비교 대상을 명시적으로 노출하고 호출 측이 weak 캡처로 라이프사이클을 직접 통제할 수 있게 한다
///
/// 격리 정책(Swift 6 strict concurrency)
/// - 글로벌 마우스 모니터: 콜백이 임의 큐에서 호출될 가능성을 보수적으로 가정하고 `Task { @MainActor }`로
///   hop한 뒤 격리 프로퍼티에 접근한다. NSEvent.mouseLocation은 thread-safe하므로 hop 전에 추출한다.
///   이 모니터는 이벤트 반환이 없는(consume) 시그니처라 hop 지연이 동작 결함으로 이어지지 않는다
/// - 로컬 마우스/키 모니터: NSEvent를 그대로 반환해야 하는 동기 시그니처라 hop으로 미루면 이벤트가
///   유실된다. AppKit 문서상 로컬 모니터 콜백은 항상 main thread에서 디스패치되므로
///   `MainActor.assumeIsolated`로 hop 없이 격리 프로퍼티에 접근하고 NSEvent 자체는 isolated 블록
///   바깥으로 캡처되지 않도록 필요한 값만 미리 추출한다(NSEvent는 Sendable이 아님)
@MainActor
final class PanelEventMonitor {

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var localKeyMonitor: Any?

    /// statusItem 버튼이 호스트하는 윈도우(메뉴바 statusItem 클릭 가드용)
    var statusItemButtonWindowProvider: (() -> NSWindow?)?

    /// 현재 표시 중인 패널 윈도우(패널 내부 클릭 가드용)
    var panelProvider: (() -> NSWindow?)?

    /// 외부 클릭 또는 ESC 키 발생 시 호출되는 dismiss 콜백
    var onDismiss: (() -> Void)?

    /// ESC 키의 macOS keyCode 상수
    private static let escapeKeyCode: UInt16 = 0x35

    /// 패널 표시 중 외부 클릭/ESC를 감지하기 위한 모니터를 등록한다
    func install() {
        remove()

        // 다른 앱 영역(외부) 클릭으로 dismiss
        // 단, 메뉴바 statusItem 버튼 영역 클릭은 제외한다. 해당 클릭은 statusItem 액션 핸들러
        // (`StatusItemController.handleClick`)가 토글로 처리하므로 글로벌 모니터에서 dismiss를
        // 호출하면 이벤트 순서상 globalMouseMonitor → statusItem 액션이 발생해 dismiss와 present가
        // 연달아 실행되며 패널이 닫히지 않고 다시 열린 상태로 유지되는 결함이 생긴다
        //
        // 글로벌 모니터는 NSEvent를 반환할 필요가 없는 fire-and-forget 시그니처이므로 hop 지연이
        // 회귀 가드(statusItem 버튼 윈도우 제외)의 동작에 영향을 주지 않는다. NSEvent 자체는
        // Sendable이 아니라 hop 전에 thread-safe한 mouseLocation을 추출해 캡처한다
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            // NSEvent.mouseLocation은 thread-safe하므로 hop 전에 캡처한다
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                guard let self else { return }

                if
                    let buttonWindow = self.statusItemButtonWindowProvider?(),
                    buttonWindow.frame.contains(location)
                {
                    return
                }
                self.onDismiss?()
            }
        }

        // 패널 영역 외 우리 앱 클릭으로 dismiss(상태바 자체 클릭은 statusItem 핸들러가 토글로 처리)
        //
        // NSStatusItem 버튼 윈도우는 우리 앱 프로세스가 호스트하므로 메뉴바 아이콘 클릭은
        // 글로벌 모니터가 아닌 로컬 모니터로 들어온다. 가드에서 statusItem 버튼 윈도우를
        // 제외하지 않으면 메뉴바 아이콘 클릭 시 dismiss → statusItem 액션 순으로 두 핸들러가
        // 연달아 fire되어 패널이 닫혔다가 즉시 다시 열리는 토글 실패가 발생한다.
        // statusItem 버튼 클릭은 항상 statusItem 액션 핸들러가 단독으로 처리하도록 한다
        //
        // 로컬 모니터는 NSEvent를 그대로 반환해야 하는 동기 시그니처라 isolation hop으로 미루면
        // 이벤트가 유실된다. AppKit 문서를 근거로 main thread 디스패치를 가정하고
        // `MainActor.assumeIsolated`로 hop 없이 self의 격리 프로퍼티에 접근한다.
        // NSEvent는 Sendable이 아니므로 비교에 필요한 window/keyCode는 isolated 블록 진입 전
        // 미리 추출해 캡처를 피한다
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            // NSEvent에서 비교에 필요한 window 참조를 isolated 진입 전에 추출한다
            let eventWindow = event.window
            MainActor.assumeIsolated {
                guard let self else { return }
                guard
                    let panel = self.panelProvider?(),
                    eventWindow !== panel,
                    eventWindow !== self.statusItemButtonWindowProvider?()
                else { return }
                self.onDismiss?()
            }
            return event
        }

        // ESC 키로 dismiss
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // keyCode를 isolated 진입 전에 추출해 NSEvent 캡처를 피한다
            let keyCode = event.keyCode
            guard keyCode == Self.escapeKeyCode else { return event }

            MainActor.assumeIsolated {
                self?.onDismiss?()
            }
            return nil
        }
    }

    func remove() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}
