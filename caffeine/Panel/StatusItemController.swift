//
//  StatusItemController.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit

/// 메뉴바 NSStatusItem 라이프사이클 + 활성 상태에 따른 아이콘 갱신 + 클릭 액션을 책임지는 컨트롤러
///
/// 활성 상태(`isActive`) 변화는 외부에서 명시적 `update(isActive:)` 호출로 받는다.
/// 1.0.1에서 매니저가 `@Published`/Combine publisher 기반에서 `@Observable`로 마이그레이션되어
/// 더 이상 `manager.$isActive` 구독이 불가능하다. 호출 측(AppDelegate)은
/// `manager.onActiveChange = { [weak controller] in controller?.update(isActive: $0) }`로
/// 콜백을 연결한다. 콜백 설계는 도메인과 인프라를 분리하는 동시에 Combine 의존을 제거한다
@MainActor
final class StatusItemController {

    /// statusItem 자체. NSStatusBar.system에 등록되어 있는 인스턴스이다
    let statusItem: NSStatusItem

    /// 메뉴바 아이콘 클릭 시 호출되는 콜백. 토글(present/dismiss) 결정은 호출 측이 담당한다
    var onClick: (() -> Void)?

    /// 초기 활성 상태. 호출 측이 매니저 현재 값을 그대로 넘긴다
    init(initialIsActive: Bool = false) {
        // 과거에는 IUO(`NSStatusItem!`)였지만 모든 접근에 implicit unwrap이 강제되어 NPE 위험이
        // 코드 곳곳에 흩어져 있었다. 컨트롤러 init에서 등록하면 이후 모든 접근이 안전하게 non-optional로
        // 동작한다. 두 번째 인스턴스가 만들어지지 않도록 컨트롤러 자체를 한 번만 만들어 보유한다
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick)

        configureImage(isActive: initialIsActive)
    }

    /// 외부에서 활성 상태 변화를 알릴 때 호출한다
    ///
    /// SwiftUI 뷰는 `@Observable` 매니저를 직접 구독해 자동 갱신되지만 statusItem 아이콘은
    /// 뷰 트리 바깥에 있어 별도 옵저버가 필요하다. AppDelegate가 매니저의 `onActiveChange`
    /// 콜백을 이 메서드로 연결한다
    func update(isActive: Bool) {
        configureImage(isActive: isActive)
    }

    @objc
    private func handleClick() {
        onClick?()
    }

    private func configureImage(isActive: Bool) {
        guard let button = statusItem.button else { return }

        let imageName = isActive ? "MenuBarIconActive" : "MenuBarIconInactive"
        let image = NSImage(named: imageName)
        image?.isTemplate = true
        button.image = image
    }

    /// 앱 종료 시 호출. statusItem을 NSStatusBar에서 제거한다
    func cleanup() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
