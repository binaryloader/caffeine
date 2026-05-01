//
//  QuickTimerSection.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 사용자 지정 입력 모드의 포커스 대상 식별자
private enum CustomTimerField: Hashable {

    case hours
    case minutes
}

/// Quick Timer 영역
///
/// v3 명세 4열 그리드(`gap: 6pt`)
/// - 8개 칩(∞ / 5분 / 15분 / 30분 / 1시간 / 2시간 / 5시간 / 사용자 지정)
/// - "사용자 지정" 칩 클릭 시 그리드를 통째로 사용자 지정 입력으로 교체
struct QuickTimerSection: View {

    @Environment(CaffeinateManager.self) private var manager
    @Environment(Preferences.self) private var preferences

    /// 사용자 지정 입력 모드 표시 여부
    @State private var showCustomInput: Bool = false

    /// 사용자 지정 입력 - 시간(문자열)
    ///
    /// `Int` binding을 쓰면 SwiftUI가 commit 시점에만 정규화 기회를 주며 입력 도중에
    /// 알파벳/특수문자/음수/범위 초과가 임시로 허용된다. `String` binding + onChange에서
    /// 직접 필터링/클램프하여 입력 시점마다 즉시 정규화한다
    @State private var customHoursText: String = "0"

    /// 사용자 지정 입력 - 분(문자열)
    @State private var customMinutesText: String = "30"

    /// 사용자 지정 모드 진입 시 첫 입력 필드에 포커스를 주기 위한 상태
    @FocusState private var focusedField: CustomTimerField?

    /// hours 허용 범위
    private let hoursRange: ClosedRange<Int> = 0 ... 23

    /// minutes 허용 범위
    private let minutesRange: ClosedRange<Int> = 0 ... 59

    /// 사용자 지정 타이머의 최소 허용 길이(초)
    ///
    /// 1분 미만은 시작 직후 즉시 만료되어 의미가 없으므로 시작 자체를 차단한다
    private static let minCustomTimerSeconds: Int = 60

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: DesignTokens.Layout.timerGridGap),
        count: 4
    )

    var body: some View {
        let strings = preferences.cachedStrings

        return Group {
            if showCustomInput {
                customInputView(strings: strings)
                    .padding(.top, DesignTokens.Layout.quickTimerCustomPaddingTop)
                    .padding(.horizontal, DesignTokens.Layout.quickTimerHeaderPaddingHorizontal)
                    .padding(.bottom, DesignTokens.Layout.quickTimerSectionPaddingBottom)
            } else {
                presetGridView(strings: strings)
                    .padding(.top, DesignTokens.Layout.quickTimerGridPaddingTop)
                    .padding(.horizontal, DesignTokens.Layout.sectionHorizontal)
                    .padding(.bottom, DesignTokens.Layout.quickTimerSectionPaddingBottom)
            }
        }
    }

    private func presetGridView(strings: LocalizedStrings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitleView(title: strings.quickTimer)
                .padding(.horizontal, DesignTokens.Layout.sectionHorizontal)
                .padding(.top, DesignTokens.Layout.sectionLabelPaddingTop)
                .padding(.bottom, DesignTokens.Layout.sectionLabelPaddingBottom)

            LazyVGrid(columns: columns, spacing: DesignTokens.Layout.timerGridGap) {
                ForEach(presets(strings: strings), id: \.seconds) { preset in
                    TimerPresetButton(
                        label: preset.label,
                        isSelected: isPresetSelected(seconds: preset.seconds),
                        action: { applyPreset(seconds: preset.seconds) },
                        accessibilityHint: strings.timerPresetAccessibilityHint
                    )
                }

                TimerPresetButton(
                    label: strings.custom,
                    isSelected: false,
                    action: { showCustomInput = true },
                    accessibilityHint: strings.timerPresetAccessibilityHint
                )
            }
            .padding(.vertical, DesignTokens.Layout.quickTimerGridOuterPaddingVertical)
        }
    }

    private func customInputView(strings: LocalizedStrings) -> some View {
        VStack(spacing: 0) {
            Text(strings.customTimer)
                .font(DesignTokens.Typography.customHeader)
                .foregroundStyle(DesignTokens.Palette.textSecondary)
                .padding(.bottom, DesignTokens.Layout.customInputHeaderPaddingBottom)

            HStack(spacing: DesignTokens.Layout.customInputFieldSpacing) {
                customNumberField(
                    text: $customHoursText,
                    range: hoursRange,
                    label: strings.hours,
                    field: .hours
                )

                Text(":")
                    .font(DesignTokens.Typography.customColon)
                    .foregroundStyle(DesignTokens.Palette.textQuaternary)
                    .padding(.bottom, DesignTokens.Layout.customColonPaddingBottom)

                customNumberField(
                    text: $customMinutesText,
                    range: minutesRange,
                    label: strings.minutes,
                    field: .minutes
                )
            }

            HStack(spacing: DesignTokens.Layout.customActionsSpacing) {
                actionButton(
                    label: strings.cancel,
                    isPrimary: false,
                    action: {
                        focusedField = nil
                        showCustomInput = false
                    }
                )

                actionButton(
                    label: strings.start,
                    isPrimary: true,
                    isDisabled: !canStartCustom,
                    action: applyCustom
                )
            }
            .padding(.top, DesignTokens.Layout.customActionsPaddingTop)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // 사용자 지정 모드 진입 직후 첫 입력 필드(시간)에 포커스를 부여한다.
            // 패널이 makeKeyAndOrderFront로 key window가 되어야 first responder가 라우팅된다.
            // SwiftUI 뷰 attach 직후에는 NSWindow first responder 협상이 끝나지 않을 수 있어
            // 다음 runloop tick으로 미룬다
            Task { @MainActor in
                focusedField = .hours
            }
        }
    }

    private func customNumberField(
        text: Binding<String>,
        range: ClosedRange<Int>,
        label: String,
        field: CustomTimerField
    ) -> some View {
        VStack(spacing: DesignTokens.Layout.customInputLabelSpacing) {
            TextField("", text: text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(DesignTokens.Typography.customNumberInput)
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .focused($focusedField, equals: field)
                .frame(width: DesignTokens.Layout.customInputFieldWidth)
                .padding(.horizontal, DesignTokens.Layout.customInputFieldPaddingHorizontal)
                .padding(.vertical, DesignTokens.Layout.customInputFieldPaddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Layout.inputRadius, style: .continuous)
                        .fill(DesignTokens.Palette.flagBadgeBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Layout.inputRadius, style: .continuous)
                        .strokeBorder(DesignTokens.Palette.inputBorder, lineWidth: 1)
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    // 입력 시점마다 즉시 정규화한다.
                    // 1) 비숫자 문자(영문/한글/특수문자/공백/마이너스 부호) 제거
                    // 2) 빈 문자열은 0으로 폴백
                    // 3) 범위 클램프 + 선두 0 정리(`05` -> `5`)
                    let filtered = newValue.filter(\.isWholeNumber)
                    let parsed = Int(filtered) ?? 0
                    let clamped = min(max(parsed, range.lowerBound), range.upperBound)
                    let normalized = String(clamped)
                    if text.wrappedValue != normalized {
                        text.wrappedValue = normalized
                    }
                }

            Text(label)
                .font(DesignTokens.Typography.customInputLabel)
                .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
    }

    /// 사용자 지정 모드의 취소/시작 버튼. 칩과 다른 padding을 가진다(footer 버튼)
    private func actionButton(
        label: String,
        isPrimary: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(DesignTokens.Typography.actionButton)
                .foregroundStyle(isPrimary ? Color.white : DesignTokens.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Layout.customActionButtonPaddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Layout.chipRadius, style: .continuous)
                        .fill(isPrimary ? DesignTokens.Palette.accent : DesignTokens.Palette.surfaceWeak)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
    }

    private func presets(strings: LocalizedStrings) -> [(label: String, seconds: Int)] {
        let labels = strings.timerLabels
        return [
            (labels.infinity, 0),
            (labels.fiveMinutes, 5 * 60),
            (labels.fifteenMinutes, 15 * 60),
            (labels.thirtyMinutes, 30 * 60),
            (labels.oneHour, 60 * 60),
            (labels.twoHours, 2 * 60 * 60),
            (labels.fiveHours, 5 * 60 * 60)
        ]
    }

    private func isPresetSelected(seconds: Int) -> Bool {
        manager.isActive && preferences.lastTimerSeconds == seconds
    }

    private func applyPreset(seconds: Int) {
        focusedField = nil
        preferences.lastTimerSeconds = seconds
        manager.start(with: preferences)
        showCustomInput = false
    }

    /// 시작 버튼 활성 조건
    ///
    /// - 두 입력 모두 정상 범위 안이어야 한다(onChange가 매번 정규화하므로 일반적으로 항상 참)
    /// - 합산 길이가 최소 1분(`minCustomTimerSeconds`) 이상이어야 한다.
    ///   1분 미만은 시작 직후 즉시 만료되어 사용자 의도와 어긋나므로 시작 자체를 차단한다
    private var canStartCustom: Bool {
        let hours = Int(customHoursText) ?? 0
        let minutes = Int(customMinutesText) ?? 0
        guard
            hoursRange.contains(hours),
            minutesRange.contains(minutes)
        else { return false }

        let totalSeconds = hours * 3600 + minutes * 60
        return totalSeconds >= Self.minCustomTimerSeconds
    }

    private func applyCustom() {
        // onChange에서 이미 정규화되지만 방어적으로 한 번 더 클램프한다
        let hours = min(max(Int(customHoursText) ?? 0, hoursRange.lowerBound), hoursRange.upperBound)
        let minutes = min(max(Int(customMinutesText) ?? 0, minutesRange.lowerBound), minutesRange.upperBound)
        let totalSeconds = hours * 3600 + minutes * 60
        // canStartCustom과 동일한 하한을 강제. UI 가드를 우회한 호출 경로가 생겨도 1분 미만은 차단
        guard totalSeconds >= Self.minCustomTimerSeconds else { return }

        focusedField = nil
        preferences.lastTimerSeconds = totalSeconds
        manager.start(with: preferences)
        showCustomInput = false
    }
}
