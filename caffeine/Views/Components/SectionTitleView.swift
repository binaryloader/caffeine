//
//  SectionTitleView.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 패널 내 섹션 라벨(QUICK TIMER, OPTIONS)
///
/// 새 디자인 핸드오프: 11pt medium, uppercase, fg-tertiary, letter-spacing 0.03em
/// 11pt 기준 0.03em ≈ 0.33pt 트래킹
struct SectionTitleView: View {

    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(DesignTokens.Typography.sectionLabel)
            .kerning(0.33)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
    }
}
