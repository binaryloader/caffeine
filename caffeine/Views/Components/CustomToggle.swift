//
//  CustomToggle.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// v3 핸드오프의 토글 스위치
///
/// 단일 사이즈 40×22pt, knob 18×18pt. 옵션 행과 헤더 메인 토글 모두 같은 크기를 쓴다
/// - ON: accent 배경, knob left=19
/// - OFF: white.opacity(0.10) 배경 + white.opacity(0.12) 보더, knob left=1.5
/// - 트랜지션: 200ms spring 근사(`DesignTokens.Motion.toggleSpring`)
///
/// 시각 표현(`visualOn`)은 외부 상태(`isOn`)와 분리되어 있다. 사용자가 토글을 탭하면
/// 노브와 트랙 색상은 즉시 spring transaction 안에서 보간되지만 외부 onTap 콜백은
/// transaction 바깥에서 실행한다. 그래야 `manager.stop()` 같은 호출이 일으키는 다른
/// 뷰 트리 변경(`CountdownContainer` 제거 등)이 같은 spring에 묶여 천천히 닫히면서
/// 패널 상단에 빈 공간이 잠시 보였다가 사라지는 회귀가 생기지 않는다
struct CustomToggle: View {

    /// 현재 ON/OFF 상태. 외부 상태(예: `manager.isActive`)를 그대로 전달한다
    let isOn: Bool

    /// 사용자가 토글을 탭했을 때 호출되는 콜백
    ///
    /// 내부에서 토글 상태를 직접 변경하지 않으므로, 호출자가 외부 상태(예: 매니저
    /// 호출, Preferences 갱신)를 책임지고 갱신해야 한다. 이 콜백은 spring transaction
    /// 바깥에서 실행되므로 콜백이 일으키는 SwiftUI 상태 변화는 즉시 반영된다(애니메이션 없음)
    let onTap: () -> Void

    /// `-u` 처럼 조건부 비활성화가 필요한 옵션을 위해 유지한다
    var isEnabled: Bool = true

    /// VoiceOver 라벨. 호출 측에서 옵션명/주제를 주입한다(LocalizedStrings 활용)
    ///
    /// ZStack + onTapGesture 조합은 VoiceOver에서 기본적으로 일반 요소로 인식되어
    /// 사용자가 어떤 토글을 다루고 있는지 알 수 없다. 호출 측에서 라벨을 명시 주입하여
    /// "Caffeine 활성화 토글", "디스플레이 잠자기 방지" 등 의미 있는 식별자를 노출한다
    let accessibilityLabel: String

    /// VoiceOver value("켜짐"/"꺼짐"). 호출 측에서 cachedStrings 기반 문구를 주입한다
    let accessibilityOnText: String

    /// VoiceOver value 비활성 상태("꺼짐"). 호출 측에서 cachedStrings 기반 문구를 주입한다
    let accessibilityOffText: String

    /// 시각 표현 전용 상태
    ///
    /// 노브 위치, 트랙 색상, 보더는 모두 `visualOn`을 본다. `isOn`이 외부에서 비동기로
    /// 바뀌면 `onChange(of: isOn)`에서 spring과 함께 동기화한다. 사용자 탭은 콜백을
    /// 부르기 전에 `visualOn`을 먼저 토글하여 시각이 즉시 반응한다
    @State private var visualOn: Bool

    init(
        isOn: Bool,
        onTap: @escaping () -> Void,
        isEnabled: Bool = true,
        accessibilityLabel: String,
        accessibilityOnText: String,
        accessibilityOffText: String
    ) {
        self.isOn = isOn
        self.onTap = onTap
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityOnText = accessibilityOnText
        self.accessibilityOffText = accessibilityOffText
        self._visualOn = State(initialValue: isOn)
    }

    /// knob 좌우 inset
    ///
    /// v3 명세는 ON 좌측 19pt / OFF 좌측 1.5pt이며 트랙 중앙 기준 오프셋으로 환산한다
    private var knobOffset: CGFloat {
        let trackWidth = DesignTokens.Layout.toggleTrackWidth
        let knobDiameter = DesignTokens.Layout.toggleKnobDiameter
        let onCenter = DesignTokens.Layout.toggleKnobOnLeftInset + knobDiameter / 2 - trackWidth / 2
        let offCenter = DesignTokens.Layout.toggleKnobOffLeftInset + knobDiameter / 2 - trackWidth / 2
        return visualOn ? onCenter : offCenter
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(visualOn ? DesignTokens.Palette.accent : DesignTokens.Palette.toggleOffTrack)

            Capsule()
                .strokeBorder(
                    visualOn ? Color.clear : DesignTokens.Palette.toggleOffBorder,
                    lineWidth: 1
                )

            Circle()
                .fill(Color.white)
                .frame(
                    width: DesignTokens.Layout.toggleKnobDiameter,
                    height: DesignTokens.Layout.toggleKnobDiameter
                )
                .shadow(
                    color: Color.black.opacity(0.3),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                .offset(x: knobOffset)
        }
        .frame(
            width: DesignTokens.Layout.toggleTrackWidth,
            height: DesignTokens.Layout.toggleTrackHeight
        )
        .opacity(isEnabled ? 1.0 : 0.35)
        .contentShape(Capsule())
        .onTapGesture {
            guard isEnabled else { return }

            // 시각만 spring transaction 안에서 즉시 토글한다.
            // 외부 onTap이 일으키는 다른 뷰 변경(CountdownContainer 제거, 패널 리사이즈 등)이
            // 같은 transaction에 묶여 보간되지 않도록 onTap은 withAnimation 바깥에서 실행한다
            withAnimation(DesignTokens.Motion.toggleSpring) {
                visualOn.toggle()
            }
            onTap()
        }
        // 외부에서 isOn이 비동기로 바뀌는 경우(예: 카운트다운 자연 종료로 manager.stop() 호출)에도
        // 시각을 spring으로 동기화한다. macOS 14 deployment target 이후 두-인자 onChange로 통일한다
        .onChange(of: isOn) { _, newValue in
            guard newValue != visualOn else { return }

            withAnimation(DesignTokens.Motion.toggleSpring) {
                visualOn = newValue
            }
        }
        // VoiceOver: ZStack의 자식 요소를 합쳐 단일 토글 요소로 노출한다.
        // - label: 호출 측이 주입한 의미(예: "디스플레이 잠자기 방지")
        // - value: 현재 상태("켜짐"/"꺼짐")
        // - traits: button + isEnabled 상태에 따라 disabled 트레잇 부여
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(isOn ? accessibilityOnText : accessibilityOffText))
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isEnabled ? [] : .isButton)
    }
}
