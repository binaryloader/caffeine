//
//  PanelHostingView.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit
import SwiftUI

/// 콘텐츠 사이즈 변화를 외부로 알려주는 NSHostingView 서브클래스
///
/// SwiftUI가 옵션 토글로 콘텐츠를 키우면 NSHostingView의 `intrinsicContentSize`가 바뀐다
/// `invalidateIntrinsicContentSize`/`layout` 시점에 새 fittingSize를 콜백으로 흘려 NSPanel이
/// 자기 contentSize를 자동으로 갱신하도록 한다
///
/// 콜백은 `layout()` 안에서 동기 호출한다. SwiftUI 콘텐츠가 즉시 줄어들 때(예: 메인 토글 OFF로
/// CountdownContainer가 사라질 때) NSPanel frame이 같은 runloop에서 따라잡지 못하면
/// 패널 상단에 빈 공간이 잠시 보였다가 닫히는 잔상이 생긴다. 동일 사이즈 가드(`lastReportedSize`)
/// 와 `applyPanelFrame`의 frame 동일성 가드, `setFrame(_:display:animate:false)`이 함께
/// 작동하여 layout 재귀가 발생해도 즉시 차단된다
///
/// generic Root는 호출 측에서 구체 타입(예: `PanelHostingView<MenuBarRootView>`)으로 명시한다.
/// `MenuBarRootView`를 `AnyView`로 감싸면 SwiftUI 식별성이 깨져 ViewUpdater가 매 프레임 트리를
/// 재구성하면서 무한 재귀로 스택 오버플로우를 일으킨 사례가 있어 절대 `AnyView`로 래핑하지 않는다
final class PanelHostingView<Root: View>: NSHostingView<Root> {

    /// 콘텐츠가 새 fittingSize를 갖게 됐을 때 호출되는 콜백
    var onContentSizeChange: ((NSSize) -> Void)?

    private var lastReportedSize: NSSize = .zero

    override func layout() {
        super.layout()
        notifyIfNeeded()
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // SwiftUI multi-pass layout 도중 임시값으로 보고하지 않도록 한 박자 미룬다.
        // SwiftUI가 같은 runloop에서 여러 번 invalidate를 호출하면 매번 fittingSize가
        // 진동하면서 NSPanel을 즉시 리사이즈해 oscillation이 발생할 수 있다.
        // 다음 runloop tick으로 한 번만 보고하면 진동이 한 사이클 안에서 안정화된 후 마지막 값으로
        // 적용된다. 다음 `layout()` 호출에서 stable fittingSize가 한 번 더 보고되어 안정화된다
        //
        // `NSHostingView`는 main actor 격리이므로 hop 없이 곧바로 격리 메서드를 호출할 수 있는
        // `DispatchQueue.main.async`를 사용한다. `RunLoop.main.perform` 클로저는
        // strict concurrency에서 nonisolated 컨텍스트로 분류되어 격리 메서드 호출에 경고를
        // 일으키므로 main DispatchQueue로 통일한다(둘 다 main runloop의 다음 tick에 실행)
        DispatchQueue.main.async { [weak self] in
            self?.notifyIfNeeded()
        }
    }

    private func notifyIfNeeded() {
        let size = fittingSize
        guard
            size.width > 0,
            size.height > 0
        else { return }

        // 동일 사이즈 반복 호출은 무시해 NSPanel 리사이즈 루프를 막는다.
        // applyPanelFrame이 setFrame을 호출한 뒤 재귀로 layout이 다시 들어와도
        // 같은 사이즈를 재차 보고하지 않으므로 무한 루프가 발생하지 않는다
        if
            abs(size.width - lastReportedSize.width) < 0.5,
            abs(size.height - lastReportedSize.height) < 0.5
        {
            return
        }

        lastReportedSize = size
        onContentSizeChange?(size)
    }
}
