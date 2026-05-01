//
//  TimerPresetButton.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// Quick Timer 4열 그리드의 칩 버튼(`PanelFooterButton` 스타일)
///
/// v3 핸드오프 명세
/// - 폰트 12pt medium, radius 10pt, 세로 padding 6pt 가로 padding 16pt
/// - 기본: white.opacity(0.10) 배경
/// - 선택됨: accent 배경 + 흰색 텍스트
struct TimerPresetButton: View {

    let label: String
    let isSelected: Bool
    let action: () -> Void

    /// VoiceOver hint("탭하여 타이머 시작"). 호출 측에서 LocalizedStrings 기반 문구를 주입한다
    /// 시간 라벨(`5분` / `5m`)은 짧아 단독으로는 동작이 무엇인지 불명확하다. hint로 보강한다
    let accessibilityHint: String?

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.Typography.chip)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Layout.chipRadius, style: .continuous)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(AccessibilityHintIfPresent(text: accessibilityHint))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignTokens.Palette.accent
        }
        // hover 시 살짝 밝은 톤 - v3 명세에는 hover가 명시되지 않았으나
        // 인터랙션 피드백으로 가벼운 강조를 더한다
        if isHovering {
            return DesignTokens.Palette.surfaceMedium
        }
        return DesignTokens.Palette.surfaceWeak
    }

    private var textColor: Color {
        isSelected ? Color.white : DesignTokens.Palette.textPrimary
    }
}

/// hint가 nil인 경우 모디파이어 자체를 적용하지 않아 빈 hint 노출을 회피한다
private struct AccessibilityHintIfPresent: ViewModifier {

    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityHint(Text(text))
        } else {
            content
        }
    }
}
