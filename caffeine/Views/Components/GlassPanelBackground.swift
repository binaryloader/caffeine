//
//  GlassPanelBackground.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit
import SwiftUI

/// 글래스 패널 배경
///
/// v3 핸드오프의 `backdrop-filter: blur(40px) saturate(160%)`를 NSVisualEffectView로 근사한다
/// material `.hudWindow`(메뉴 패널과 동일한 강한 블러) + `.behindWindow` blendingMode 조합이
/// 웹 saturate와 가장 비슷한 시각 근사를 만든다
///
/// vibrancy 표면을 외곽 보더와 정확히 정렬하기 위해 `wantsLayer + cornerRadius + masksToBounds`로
/// 직접 라운드 마스킹한다. 부모 `clipShape`만으로는 vibrancy 내부 사각 모서리가 보더 안쪽에
/// 비치는 누수가 있었다
///
/// vibrancy 외형은 `.vibrantDark`로 고정한다(다크 강제 근거는 `MenuBarContentView.panelBackground`)
struct GlassPanelBackground: NSViewRepresentable {

    /// NSVisualEffectView material. 기본은 hudWindow(메뉴 패널과 같은 강한 블러)
    var material: NSVisualEffectView.Material = .hudWindow

    /// blending mode. behind는 윈도우 뒤 배경을 블러한다(메뉴바 앱 패널의 표준 동작)
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    /// 라운드 모서리 반지름. 외곽 보더와 동일한 값을 사용해 정렬을 맞춘다
    var cornerRadius: CGFloat = DesignTokens.Layout.panelRadius

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = NSAppearance(named: .vibrantDark)
        // 마우스 이벤트가 SwiftUI 콘텐츠로 통과되도록 강조 표시는 끈다
        view.isEmphasized = false

        // vibrancy 표면을 정확한 라운드 모양으로 마스킹한다.
        // 외곽 RoundedRectangle stroke와 동일한 cornerRadius로 둘이 시각적으로 정렬된다
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        // 시스템 외형이 바뀌어도 다크가 유지되도록 매번 강제 적용한다
        nsView.appearance = NSAppearance(named: .vibrantDark)
        // layer가 재생성되었을 때를 대비해 매번 갱신한다
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.cornerCurve = .continuous
        nsView.layer?.masksToBounds = true
    }
}
