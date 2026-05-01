//
//  FooterCreditView.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit
import SwiftUI

/// 패널 최하단 GitHub 크레딧 라인
///
/// `@binaryloader` 핸들을 한 줄로 표시한다. 클릭하면 기본 브라우저로 GitHub
/// 프로필을 연다. 메인 UI를 방해하지 않도록 fg-tertiary 톤과 작은 폰트를 사용하며
/// hover 시에만 fg-secondary로 톤을 한 단계 올린다
///
/// 클릭 동작은 SwiftUI `Link` 대신 `Button` + `NSWorkspace.shared.open` 패턴을
/// 사용한다. 패널이 `.nonactivatingPanel`로 떠 있어 `Link`가 내부적으로 수행하는
/// NSApp 활성화 협상이 패널 first responder/key window 상태와 충돌할 가능성을
/// 피하기 위함이다. NSWorkspace 호출로 다른 앱(브라우저)이 활성화되면
/// `AppDelegate`의 글로벌 마우스/앱 비활성화 모니터가 패널을 자연스럽게 닫는다
struct FooterCreditView: View {

    @Environment(Preferences.self) private var preferences

    /// 표시할 GitHub 핸들. 핸들 자체는 번역 대상이 아니다
    let handle: String

    /// 클릭 시 열 URL
    let url: URL

    @State private var isHovering: Bool = false

    var body: some View {
        let strings = preferences.cachedStrings
        return Button(action: openURL) {
            Text("@\(handle)")
                .font(DesignTokens.Typography.footerCredit)
                .foregroundStyle(isHovering ? DesignTokens.Palette.textSecondary : DesignTokens.Palette.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Layout.footerPaddingVertical)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(strings.githubProfile) @\(handle)"))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func openURL() {
        NSWorkspace.shared.open(url)
    }
}
