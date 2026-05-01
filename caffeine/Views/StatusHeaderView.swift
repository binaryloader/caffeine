//
//  StatusHeaderView.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit
import SwiftUI

/// 패널 헤더
///
/// v3 핸드오프 명세에서 좌측 커피컵 아이콘은 제거되었다(중복 시각 신호 정리)
/// - 좌측: "Caffeine" 15pt semibold + "· 활성/비활성" 11pt medium 한 줄
///   상태 라벨은 활성 시 accent, 비활성 시 fg-tertiary로 표기한다
/// - 우측: 기어 28×28 + 종료 28×28 + 메인 토글 40×22 (gap 6pt)
struct StatusHeaderView: View {

    @Environment(CaffeinateManager.self) private var manager
    @Environment(Preferences.self) private var preferences

    /// 기어 버튼 클릭 콜백. 옵션 패널 토글
    let onSettingsTap: () -> Void

    /// 옵션 패널이 펼쳐져 있는지 여부. 기어 버튼 활성 표시에 사용
    let isSettingsOpen: Bool

    var body: some View {
        let strings = preferences.cachedStrings

        return HStack(alignment: .center, spacing: 0) {
            titleGroup(strings: strings)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DesignTokens.Layout.headerActionsSpacing) {
                HeaderIconButton(
                    assetName: "IconGear",
                    iconSize: 14,
                    hoverBackground: DesignTokens.Palette.surfaceWeak,
                    isActive: isSettingsOpen,
                    accessibilityTitle: strings.options,
                    accessibilityActiveText: strings.optionsExpandedAccessibility,
                    accessibilityInactiveText: strings.optionsCollapsedAccessibility,
                    action: onSettingsTap
                )
                // macOS 환경설정 관용에 따라 옵션 펼침/접힘에 Cmd+, 단축키를 부여한다
                .keyboardShortcut(",", modifiers: .command)

                HeaderIconButton(
                    assetName: "IconQuit",
                    iconSize: 14,
                    hoverBackground: DesignTokens.Palette.dangerHover,
                    accessibilityTitle: strings.quit,
                    action: quit
                )

                CustomToggle(
                    isOn: manager.isActive,
                    onTap: toggleMain,
                    accessibilityLabel: strings.mainToggleAccessibilityLabel,
                    accessibilityOnText: strings.toggleOnAccessibility,
                    accessibilityOffText: strings.toggleOffAccessibility
                )
                // 패널이 key window인 동안 Space로 메인 토글을 ON/OFF한다.
                // 메뉴바 패널 특성상 단축키는 패널이 표시된 동안에만 동작한다.
                // Space는 시스템 단축키와 충돌이 적고 macOS HIG의 "기본 액션" 관용에 부합한다(예: Quick Look)
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    /// 타이틀 + 상태 한 줄
    ///
    /// 좌측 커피컵 아이콘은 제거되었다. 헤더 좌측 정렬은 `headerPaddingHorizontal`(18pt)이
    /// 그대로 잡아 주므로 별도 leading inset은 추가하지 않는다
    private func titleGroup(strings: LocalizedStrings) -> some View {
        // "Caffeine"과 상태 텍스트 사이 gap은 4pt(v3 명세)
        HStack(spacing: DesignTokens.Layout.headerTitleStatusSpacing) {
            Text("Caffeine")
                .font(DesignTokens.Typography.headerTitle)
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("· \(statusText(strings: strings))")
                .font(DesignTokens.Typography.headerStatus)
                .foregroundStyle(manager.isActive ? DesignTokens.Palette.accent : DesignTokens.Palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    /// 헤더 상태 문구. 카운트다운은 별도 영역에서 보여주므로 여기서는 활성/비활성만 표기한다
    private func statusText(strings: LocalizedStrings) -> String {
        manager.isActive ? strings.active : strings.inactive
    }

    /// 헤더 메인 토글 탭. `manager.isActive`를 보고 반대 상태로 전환한다
    ///
    /// `CustomToggle`의 onTap이 `withAnimation` transaction 안에서 호출하기 때문에
    /// 매니저 상태 변화가 SwiftUI에 전파될 때도 같은 transaction을 따라 한 번만
    /// 깔끔하게 애니메이션된다
    private func toggleMain() {
        if manager.isActive {
            manager.stop()
        } else {
            manager.activateInfinite(with: preferences)
        }
    }

    /// 자식 caffeinate 정리 후 앱 종료
    private func quit() {
        manager.stop()
        NSApplication.shared.terminate(nil)
    }
}
