//
//  HeaderIconButton.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 헤더 우측의 28×28 아이콘 버튼(기어/Quit 공용)
///
/// 새 디자인 핸드오프: 28×28 hit, radius 8, hover 시 배경 변경
struct HeaderIconButton: View {

    /// 아이콘 자산 이름(`IconGear`/`IconQuit`)
    let assetName: String

    /// 아이콘 자체 폰트 사이즈(SVG는 `currentColor` + `font` 기반)
    let iconSize: CGFloat

    /// hover 시 사용할 배경 색
    let hoverBackground: Color

    /// 활성 표시(설정 패널이 열려 있을 때 기어 버튼에 사용)
    var isActive: Bool = false

    /// 접근성 라벨
    let accessibilityTitle: String

    /// VoiceOver value(활성 상태 텍스트). 기어 버튼처럼 `isActive`를 가진 경우만 의미가 있다
    /// 비활성 상태 토글에는 nil을 주입하면 value가 노출되지 않는다
    var accessibilityActiveText: String?
    var accessibilityInactiveText: String?

    /// 클릭 콜백
    let action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(DesignTokens.Palette.textSecondary)
                .frame(
                    width: DesignTokens.Layout.iconButtonSize,
                    height: DesignTokens.Layout.iconButtonSize
                )
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Layout.iconButtonRadius, style: .continuous)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityTitle))
        .modifier(AccessibilityValueIfPresent(text: accessibilityValueText))
        .onHover { hovering in
            // hover 배경 트랜지션은 패널 리사이즈 트랜잭션과 섞이면 잔향을 만들 수
            // 있어 즉시 반영한다
            isHovering = hovering
        }
    }

    /// `isActive` 상태와 호출 측이 주입한 텍스트가 모두 있을 때만 VoiceOver value를 만든다
    private var accessibilityValueText: String? {
        guard
            let activeText = accessibilityActiveText,
            let inactiveText = accessibilityInactiveText
        else { return nil }

        return isActive ? activeText : inactiveText
    }

    private var backgroundColor: Color {
        if isActive {
            return DesignTokens.Palette.surfaceHover
        }
        return isHovering ? hoverBackground : Color.clear
    }
}

/// `accessibilityValue`는 빈 텍스트를 주어도 VoiceOver가 값으로 읽기 때문에 nil인 경우는
/// 모디파이어 자체를 적용하지 않아 값 노출을 회피한다
private struct AccessibilityValueIfPresent: ViewModifier {

    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityValue(Text(text))
        } else {
            content
        }
    }
}
