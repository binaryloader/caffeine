//
//  OptionsSection.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 설정 섹션
///
/// 헤더 기어 클릭 시 토글되는 영역. 두 PanelSection을 세로로 배치한다
/// - 잠자기 방지 옵션(d/i/m/s/u)
/// - 앱 설정(자동 시작 + 언어 선택)
struct OptionsSection: View {

    @Environment(CaffeinateManager.self) private var manager
    @Environment(Preferences.self) private var preferences
    @Environment(LoginItemManager.self) private var loginItem

    var body: some View {
        let strings = preferences.cachedStrings

        return VStack(alignment: .leading, spacing: 4) {
            sleepFlagsSection(strings: strings)

            // 두 섹션 사이 1px 구분선
            Rectangle()
                .fill(DesignTokens.Palette.separator)
                .frame(height: 1)
                .padding(.horizontal, DesignTokens.Layout.separatorHorizontalInset)
                .padding(.vertical, DesignTokens.Layout.optionsInnerSeparatorVerticalPadding)

            appPreferencesSection(strings: strings)
        }
    }

    /// 잠자기 방지 5개 옵션을 묶는 섹션
    private func sleepFlagsSection(strings: LocalizedStrings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitleView(title: strings.options)
                .padding(.top, DesignTokens.Layout.sectionLabelPaddingTop)
                .padding(.horizontal, DesignTokens.Layout.sectionLabelPaddingHorizontalIndented)
                .padding(.bottom, DesignTokens.Layout.sectionLabelPaddingBottom)

            VStack(spacing: 0) {
                ForEach(strings.flags, id: \.flag) { flag in
                    OptionRow(flag: flag)
                }
            }
            .padding(.horizontal, DesignTokens.Layout.sectionHorizontal)
            .padding(.bottom, DesignTokens.Layout.sectionLabelPaddingBottom)
        }
    }

    /// 앱 자체 설정(자동 시작/언어)을 묶는 섹션
    private func appPreferencesSection(strings: LocalizedStrings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitleView(title: strings.appSettings)
                .padding(.top, DesignTokens.Layout.sectionLabelPaddingTop)
                .padding(.horizontal, DesignTokens.Layout.sectionLabelPaddingHorizontalIndented)
                .padding(.bottom, DesignTokens.Layout.sectionLabelPaddingBottom)

            VStack(spacing: 0) {
                LoginItemRow()
                LanguagePickerRow()
            }
            .padding(.horizontal, DesignTokens.Layout.sectionHorizontal)
            .padding(.bottom, DesignTokens.Layout.sectionLabelPaddingBottom)
        }
    }
}

/// 옵션 한 행
///
/// v3 명세
/// - left: 옵션명 13pt + 플래그 뱃지(10pt mono / radius 6 / `rgba(255,255,255,0.08)` bg)
///   + 설명 12pt fg-tertiary line-height 1.4
/// - right: 40×22 토글
///
/// 행의 시각 외피(hover 강조, padding, 모서리)는 `PanelOptionRow`가 담당한다.
/// 같은 외피를 쓰는 `LoginItemRow`/`LanguagePickerRow`와 디자인 토큰을 한 곳에서 통제한다
private struct OptionRow: View {

    let flag: LocalizedStrings.FlagText

    @Environment(CaffeinateManager.self) private var manager
    @Environment(Preferences.self) private var preferences

    var body: some View {
        let isEnabled = self.isEnabled()
        let isOn = self.currentValue()
        let strings = preferences.cachedStrings

        return PanelOptionRow(
            isEnabled: isEnabled,
            leading: {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.rowLabelStackSpacing) {
                    HStack(spacing: DesignTokens.Layout.rowLabelFlagSpacing) {
                        Text(flag.label)
                            .font(DesignTokens.Typography.optionLabel)
                            .foregroundStyle(DesignTokens.Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        flagBadge
                    }

                    Text(flag.description)
                        .font(DesignTokens.Typography.optionDesc)
                        .foregroundStyle(DesignTokens.Palette.textTertiary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            },
            trailing: {
                CustomToggle(
                    isOn: isOn,
                    onTap: toggleFlag,
                    isEnabled: isEnabled,
                    accessibilityLabel: flag.label,
                    accessibilityOnText: strings.toggleOnAccessibility,
                    accessibilityOffText: strings.toggleOffAccessibility
                )
            }
        )
    }

    /// `-d` 같은 monospace 플래그 뱃지
    private var flagBadge: some View {
        Text(flag.flag.cliArgument)
            .font(DesignTokens.Typography.flagBadge)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .padding(.horizontal, DesignTokens.Layout.flagBadgePaddingHorizontal)
            .padding(.vertical, DesignTokens.Layout.flagBadgePaddingVertical)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Layout.flagBadgeRadius, style: .continuous)
                    .fill(DesignTokens.Palette.flagBadgeBackground)
            )
    }

    /// SleepFlag에 대응하는 Preferences 현재 값(subscript 경유)
    private func currentValue() -> Bool {
        preferences[flag.flag]
    }

    /// 옵션 토글 탭 처리. Preferences를 갱신하고 활성 중이면 caffeinate를 재시작한다
    ///
    /// 옛 String key dispatch + key path는 SleepFlag enum 도입으로 제거되었다. enum subscript는
    /// 새 case 추가 시 dispatch 분기를 별도로 손볼 필요 없이 read/write 경로가 자동 따라온다
    private func toggleFlag() {
        preferences[flag.flag].toggle()
        manager.restartIfActive(with: preferences)
    }

    /// timerOnly 플래그(`-u`)는 caffeinate(8)상 `-t`와 함께일 때만 동작하지만, 그 사실 때문에
    /// 토글을 항상 잠그면 비활성 상태에서 미리 ON으로 설정해 두는 사용 흐름이 막힌다.
    /// 잠가야 하는 케이스는 정확히 하나뿐이다 - 활성 + 무제한(타이머 0). 그 외에는 자유롭게 토글한다.
    /// 결정 로직 자체는 테스트 가능성을 위해 `SleepFlag.isToggleEnabled(for:isActive:timerSeconds:)`로 분리되어 있다.
    /// 과거에는 `flag.key == "user"` 문자열 비교였지만 SleepFlag.isTimerOnly로 통합되었다
    private func isEnabled() -> Bool {
        SleepFlag.isToggleEnabled(
            for: flag.flag,
            isActive: manager.isActive,
            timerSeconds: preferences.lastTimerSeconds
        )
    }
}

/// 자동 로그인 시작 토글 행
///
/// 옵션 행과 동일한 레이아웃으로 통일감을 유지한다(설명 텍스트 + 우측 40×22 토글)
private struct LoginItemRow: View {

    @Environment(Preferences.self) private var preferences
    @Environment(LoginItemManager.self) private var loginItem

    var body: some View {
        let strings = preferences.cachedStrings

        return PanelOptionRow(
            leading: {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.rowLabelStackSpacing) {
                    Text(strings.launchAtLogin)
                        .font(DesignTokens.Typography.optionLabel)
                        .foregroundStyle(DesignTokens.Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    // 등록/해제가 실패했다면 설명 자리에 안내 메시지를 띄운다.
                    // SMAppService.register/unregister는 시스템 설정에서 사용자가 차단했거나
                    // 권한이 미부여된 환경에서 실패한다. 사용자가 다음 단계(시스템 설정)를 알도록 한다
                    Text(loginItem.lastError != nil ? strings.launchAtLoginErrorHint : strings.launchAtLoginDescription)
                        .font(DesignTokens.Typography.optionDesc)
                        .foregroundStyle(DesignTokens.Palette.textTertiary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            },
            trailing: {
                CustomToggle(
                    isOn: loginItem.isEnabled,
                    onTap: { loginItem.setEnabled(!loginItem.isEnabled) },
                    accessibilityLabel: strings.launchAtLoginAccessibilityLabel,
                    accessibilityOnText: strings.toggleOnAccessibility,
                    accessibilityOffText: strings.toggleOffAccessibility
                )
            }
        )
        .onAppear {
            // 사용자가 시스템 설정에서 직접 끈 경우 등 외부 변경에 동기화한다
            loginItem.refresh()
        }
    }
}

/// 언어 선택 행. 우측에 칩 형태의 segmented picker를 둔다
private struct LanguagePickerRow: View {

    @Environment(Preferences.self) private var preferences

    var body: some View {
        let strings = preferences.cachedStrings

        return PanelOptionRow(
            leading: {
                Text(strings.language)
                    .font(DesignTokens.Typography.optionLabel)
                    .foregroundStyle(DesignTokens.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            },
            trailing: {
                languageSegments(strings: strings)
            }
        )
    }

    /// 한/영/일 3개 칩으로 즉시 전환되는 segmented control
    private func languageSegments(strings: LocalizedStrings) -> some View {
        HStack(spacing: DesignTokens.Layout.languageSegmentsSpacing) {
            ForEach(AppLanguage.allCases, id: \.self) { language in
                LanguageSegmentChip(
                    label: language.shortLabel,
                    isSelected: preferences.appLanguage == language,
                    action: { preferences.appLanguage = language }
                )
            }
        }
        .padding(DesignTokens.Layout.languageSegmentsOuterPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.chipRadius, style: .continuous)
                .fill(DesignTokens.Palette.surfaceWeak)
        )
        // 컨테이너 라벨로 "언어 선택"을 노출. 자식 칩은 각자 KO/EN/JA로 식별된다
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(strings.languageAccessibilityLabel))
    }
}

/// 언어 segmented control의 단일 칩
private struct LanguageSegmentChip: View {

    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.Typography.chip)
                .foregroundStyle(isSelected ? Color.white : DesignTokens.Palette.textPrimary)
                .padding(.horizontal, DesignTokens.Layout.languageSegmentChipPaddingHorizontal)
                .padding(.vertical, DesignTokens.Layout.languageSegmentChipPaddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Layout.flagBadgeRadius, style: .continuous)
                        .fill(background)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var background: Color {
        if isSelected { return DesignTokens.Palette.accent }
        if isHovering { return DesignTokens.Palette.surfaceWeak }

        return Color.clear
    }
}
