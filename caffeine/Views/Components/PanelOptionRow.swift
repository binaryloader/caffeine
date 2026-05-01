//
//  PanelOptionRow.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 패널 옵션 섹션의 표준 행 레이아웃
///
/// `OptionsSection`의 `OptionRow`/`LoginItemRow`/`LanguagePickerRow`가 모두 같은
/// 시각 구조(좌측 라벨 + 우측 컨트롤 + hover 강조)를 반복하던 것을 한 곳에서 정의한다.
/// hover 톤(`rowHover`), 모서리(`rowRadius`), padding(`rowPaddingHorizontal/Vertical`)을
/// 한 군데에서 관리해 전 행이 같은 디자인 토큰을 따른다는 인변량을 유지한다
///
/// - `leading`: 좌측 라벨 영역. 단순 텍스트인 경우와 라벨 + 보조 라인(설명) 같은 합성
///   레이아웃을 모두 받기 위해 슬롯으로 분리한다. 호출 측에서 폰트/라인 스페이싱 등
///   세부 표현을 직접 통제할 수 있다
/// - `trailing`: 우측 컨트롤 영역(`CustomToggle` / segmented control 등)
/// - `isEnabled`: 비활성 행은 hover 강조를 주지 않고 컨트롤 자체도 흐리게 표시한다
///   (`isEnabled = false`이면 opacity를 직접 적용해 행 전체 톤을 떨어뜨린다)
struct PanelOptionRow<Leading: View, Trailing: View>: View {

    let isEnabled: Bool
    let leading: () -> Leading
    let trailing: () -> Trailing

    @State private var isHovering: Bool = false

    init(
        isEnabled: Bool = true,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.isEnabled = isEnabled
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Layout.rowContentSpacing) {
            leading()
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.horizontal, DesignTokens.Layout.rowPaddingHorizontal)
        .padding(.vertical, DesignTokens.Layout.rowPaddingVertical)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.rowRadius, style: .continuous)
                .fill(isHovering ? DesignTokens.Palette.rowHover : Color.clear)
        )
        .opacity(isEnabled ? 1.0 : 0.4)
        .onHover { hovering in
            // 비활성 행은 hover 강조를 주지 않는다. 일관된 시각 신호를 위해 단일 분기로 처리
            guard isEnabled else {
                if isHovering { isHovering = false }
                return
            }

            isHovering = hovering
        }
    }
}
