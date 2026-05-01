//
//  MenuBarContentView.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 메뉴바 패널 루트 컨텐츠
///
/// v3 핸드오프의 380pt 글래스모피즘 단일 패널. 구조는 아래와 같다
/// - 헤더(StatusHeaderView)
/// - 카운트다운(타이머 활성 시)
/// - 옵션 패널(기어 토글 시) + 구분선
/// - Quick Timer 또는 사용자 지정 입력
struct MenuBarContentView: View {

    @Environment(CaffeinateManager.self) private var manager
    @Environment(Preferences.self) private var preferences

    /// 옵션 패널 펼침 여부
    @State private var showSettings: Bool = false

    /// GitHub 크레딧 푸터의 링크 URL
    ///
    /// 정적이며 컴파일 타임에 검증 가능한 문자열이지만 강제 unwrap을 시각적으로 줄이기 위해
    /// 정적 상수로 분리한다. 만에 하나 nil이 되더라도 앱 시작 시점에 즉시 fatal로 잡히도록
    /// 강제 unwrap을 유지하되 노출 빈도를 1회로 한정한다
    private static let creditURL: URL = URL(string: "https://github.com/binaryloader")!

    var body: some View {
        let strings = preferences.cachedStrings
        return VStack(alignment: .leading, spacing: 0) {
            StatusHeaderView(
                onSettingsTap: { showSettings.toggle() },
                isSettingsOpen: showSettings
            )
            .padding(.top, DesignTokens.Layout.headerPaddingTop)
            .padding(.horizontal, DesignTokens.Layout.headerPaddingHorizontal)
            .padding(.bottom, DesignTokens.Layout.headerPaddingBottom)

            // 카운트다운: 매초 갱신되는 `manager.remainingSeconds`를 부모가 직접 구독하면
            // 부모 VStack 전체가 매초 재평가되어 헤더의 `CustomToggle` 정체성/transaction에
            // 영향을 줄 수 있다. 매니저 구독을 `CountdownContainer` 내부로 한정해 헤더는
            // `manager.isActive`만 보고 카운트다운 갱신과 격리되도록 한다
            CountdownContainer(leftSuffix: strings.left)
            separator

            if showSettings {
                OptionsSection()
                separator
            }

            QuickTimerSection()

            // v3 패널 최하단 여백
            Spacer().frame(height: DesignTokens.Layout.panelBottomSpacing)

            separator

            // GitHub 크레딧 푸터(메인 UI를 방해하지 않는 fg-tertiary 톤 한 줄)
            FooterCreditView(
                handle: "binaryloader",
                url: Self.creditURL
            )
        }
        .frame(width: DesignTokens.Layout.windowWidth)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.panelRadius, style: .continuous)
                .strokeBorder(DesignTokens.Palette.panelBorder, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(DesignTokens.Layout.panelShadowOpacity),
            radius: DesignTokens.Layout.panelShadowRadius,
            x: 0,
            y: DesignTokens.Layout.panelShadowYOffset
        )
        .preferredColorScheme(.dark)
    }

    /// v3 글래스 패널 배경
    ///
    /// 패널은 시스템 외형과 무관하게 항상 다크 룩이다(NSPanel `.darkAqua`,
    /// NSVisualEffectView `.vibrantDark`, SwiftUI `.preferredColorScheme(.dark)` 3중 강제).
    /// Spotlight/Control Center가 같은 패턴을 따른다. NSVisualEffectView vibrantDark 표면 위에
    /// 검정 25% 오버레이를 얹어 흰 텍스트(`fg-primary` 92%) 대비를 확보한다. 다크 강제 결정의
    /// 단일 근거 주석은 이 위치에 둔다(다른 다크 강제 지점은 이 주석을 참조)
    private var panelBackground: some View {
        ZStack {
            GlassPanelBackground()
            DesignTokens.Palette.glassOverlay
        }
    }

    /// 패널 내 1px 구분선
    private var separator: some View {
        Rectangle()
            .fill(DesignTokens.Palette.separator)
            .frame(height: 1)
            .padding(.horizontal, DesignTokens.Layout.separatorHorizontalInset)
    }
}

/// 카운트다운을 매니저로부터 직접 구독하는 컨테이너
///
/// 매초 갱신되는 `manager.remainingSeconds`를 부모(MenuBarContentView)가 보지 않도록
/// 카운트다운 표시와 separator를 이 뷰 안으로 격리한다. 부모는 더 이상 `remainingSeconds`
/// 변화에 따라 재렌더링되지 않으며 헤더 `CustomToggle`의 시각적 흔들림 회귀를 막는다.
/// 표시할 카운트다운이 없을 때는 빈 뷰(`EmptyView`)를 반환해 layout 영향을 0으로 만든다
///
/// `.transaction { $0.animation = nil }`을 적용해 외부에서 어떤 transaction이 들어와도
/// 등장/소멸은 즉시 반영된다. CustomToggle이 `withAnimation` 바깥에서 매니저 호출을
/// 실행하도록 분리되어 있지만, 다른 경로(타이머 칩, 자동 시작 등)에서 카운트다운이
/// 외부 transaction에 묶여 천천히 닫히는 경우를 방지하는 안전망이다
private struct CountdownContainer: View {

    @Environment(CaffeinateManager.self) private var manager

    let leftSuffix: String

    var body: some View {
        Group {
            if
                manager.isActive,
                let remaining = manager.remainingSeconds,
                remaining > 0
            {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(DesignTokens.Palette.separator)
                        .frame(height: 1)
                        .padding(.horizontal, DesignTokens.Layout.separatorHorizontalInset)

                    CountdownView(
                        remainingSeconds: remaining,
                        leftSuffix: leftSuffix
                    )
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

/// 카운트다운 표시
///
/// v3 명세: 18pt monospaced semibold accent 컬러 + "남음" 라벨 12pt fg-tertiary.
/// 카운트다운이 길이 단위(시:분:초 vs 분:초)로 바뀔 때 부모 layout이 흔들리지 않도록
/// 고정 높이 프레임을 적용한다
private struct CountdownView: View {

    let remainingSeconds: Int
    let leftSuffix: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(formatted)
                .font(DesignTokens.Typography.countdown)
                .foregroundStyle(DesignTokens.Palette.accent)
                .kerning(0.7)

            Text(leftSuffix)
                .font(DesignTokens.Typography.countdownLabel)
                .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.Layout.countdownHeight)
        .padding(.horizontal, DesignTokens.Layout.headerPaddingHorizontal)
    }

    private var formatted: String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}
