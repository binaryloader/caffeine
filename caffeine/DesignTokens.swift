//
//  DesignTokens.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 디자인 핸드오프 v3의 토큰을 한 곳에서 관리한다
///
/// `colors_and_type.css`의 디자인 토큰과 README v3의 Glass Panel / Typography /
/// Toggle 명세를 1:1 매핑한다. 패널은 시스템 외형과 무관하게 항상 다크로 강제되므로
/// 팔레트는 다크 단일 변형으로 정의한다(상세 근거는 `MenuBarContentView.panelBackground`)
enum DesignTokens {

    enum Palette {

        /// 글래스 패널 위에 얹히는 톤 오버레이
        ///
        /// vibrantDark 표면이 그대로 노출되면 흰 텍스트 대비가 부족하여 검정 오버레이로 가라앉힌다.
        /// 0.18은 vibrancy의 색감을 거의 유지하지만 옵션 행/카운트다운의 흰색 텍스트가 잘 안 보이는
        /// 환경(밝은 배경 위 패널)이 남았다. 0.25로 올리면 vibrancy의 채도/투명감은 유지되면서
        /// 패널 표면 평균 luminance가 한 단계 더 떨어져 fg-primary(92%)와 fg-secondary(60%)
        /// 모두 WCAG AA에 가까운 대비를 확보한다(0.30 이상은 vibrancy를 죽여 글래스가 평면 검정으로 보임)
        static let glassOverlay = Color.black.opacity(0.25)

        /// 패널 외곽선
        ///
        /// v3 명세 `rgba(255,255,255, 0.15)`
        static let panelBorder = Color.white.opacity(0.15)

        /// 본문 1차 텍스트(`fg-primary`, 92% white)
        static let textPrimary = Color.white.opacity(0.92)

        /// 본문 2차 텍스트(`fg-secondary`, 60% white)
        static let textSecondary = Color.white.opacity(0.60)

        /// 본문 3차 텍스트(`fg-tertiary`, 35% white)
        static let textTertiary = Color.white.opacity(0.35)

        /// 본문 4차 텍스트(`fg-quaternary`, 18% white)
        static let textQuaternary = Color.white.opacity(0.18)

        /// 활성 상태 액센트
        ///
        /// `NSColor.controlAccentColor`(시스템 환경설정의 강조 색상)을 SwiftUI Color로 래핑한다
        /// 사용자가 시스템 강조 색상을 변경하면 즉시 반영된다
        static let accent = Color(nsColor: .controlAccentColor)

        /// Quit 버튼 hover 시 빨간 hover 배경
        ///
        /// v3에는 명시되지 않았지만 종료 버튼의 위험 신호를 시각적으로 강조하기 위해 유지한다
        static let dangerHover = Color(red: 1.0, green: 80.0 / 255.0, blue: 80.0 / 255.0).opacity(0.15)

        /// 토글 OFF 트랙
        ///
        /// v3 명세 `rgba(255,255,255, 0.10)`
        static let toggleOffTrack = Color.white.opacity(0.10)

        /// 토글 OFF 외곽선
        ///
        /// v3 명세 `rgba(255,255,255, 0.12)`
        static let toggleOffBorder = Color.white.opacity(0.12)

        /// 칩 기본 배경
        ///
        /// v3 명세 `rgba(255,255,255, 0.10)`
        static let surfaceWeak = Color.white.opacity(0.10)

        /// 칩/아이콘 hover 배경
        ///
        /// v3 명세 `bg-active = rgba(255,255,255, 0.10)`. hover와 선택 비활성 사이의 시각 구분을
        /// 위해 hover는 약간 더 어둡게 유지한다(`bg-hover = rgba(255,255,255, 0.06)`)
        static let surfaceHover = Color.white.opacity(0.06)

        /// 옵션 행 hover 배경
        ///
        /// v3 명세 `rgba(255,255,255, 0.06)`
        static let rowHover = Color.white.opacity(0.06)

        /// 입력 필드 보더
        static let inputBorder = Color.white.opacity(0.10)

        /// 패널 내 1px 구분선
        ///
        /// v3 명세 `rgba(255,255,255, 0.08)`
        static let separator = Color.white.opacity(0.08)

        /// CLI 플래그 뱃지 배경
        ///
        /// v3 명세 `rgba(255,255,255, 0.08)`
        static let flagBadgeBackground = Color.white.opacity(0.08)

        /// 칩/세그먼트 hover 시 한 단계 밝은 톤
        ///
        /// `surfaceWeak`(0.10)보다 약간 더 밝은 0.14를 사용해 hover 피드백을 명시한다.
        /// `TimerPresetButton` hover, `LanguageSegmentChip` hover 등에서 공유한다
        static let surfaceMedium = Color.white.opacity(0.14)
    }

    enum Layout {

        /// 윈도우 폭. v3 명세 380pt
        static let windowWidth: CGFloat = 380

        /// 패널 외곽 모서리. v3 명세 24pt
        static let panelRadius: CGFloat = 24

        /// 그림자 값. `0 16px 48px rgba(0,0,0,0.40)`
        static let panelShadowOpacity: Double = 0.40
        static let panelShadowRadius: CGFloat = 24
        static let panelShadowYOffset: CGFloat = 16

        /// 헤더 padding. v3 명세 `14px 18px 10px`
        static let headerPaddingTop: CGFloat = 14
        static let headerPaddingHorizontal: CGFloat = 18
        static let headerPaddingBottom: CGFloat = 10

        /// 옵션/타이머 섹션 좌우 padding(섹션 컨테이너)
        static let sectionHorizontal: CGFloat = 10

        /// 섹션 라벨 padding. v3 MenuBarPanel `8px 10px 4px` 기준이지만 옵션 펼친 상태에서
        /// 13" 노트북 가용 높이(약 720~820pt) 안에 헤더 + 5개 옵션 + 앱 설정 + 빠른 타이머가
        /// 모두 들어가도록 top만 6pt로 미세 조정
        static let sectionLabelPaddingTop: CGFloat = 6
        static let sectionLabelPaddingHorizontal: CGFloat = 10
        static let sectionLabelPaddingBottom: CGFloat = 4

        /// 옵션 행 padding. v3 MenuBarPanel `7px 10px`
        static let rowPaddingVertical: CGFloat = 7
        static let rowPaddingHorizontal: CGFloat = 10

        /// 옵션 행 radius
        static let rowRadius: CGFloat = 12

        /// 칩 radius
        static let chipRadius: CGFloat = 10

        /// 입력 필드 radius
        static let inputRadius: CGFloat = 14

        /// 아이콘 버튼 hit target. v3 명세 28×28
        static let iconButtonSize: CGFloat = 28

        /// 아이콘 버튼 radius. v3 명세 8pt
        static let iconButtonRadius: CGFloat = 8

        /// 헤더 우측 액션 그룹 spacing. v3 명세 6pt
        static let headerActionsSpacing: CGFloat = 6

        /// 칩 그리드 gap. v3 명세 6pt
        static let timerGridGap: CGFloat = 6

        /// CLI 플래그 뱃지 radius. v3 명세 6pt
        static let flagBadgeRadius: CGFloat = 6

        /// 패널 1px 구분선 좌우 inset(헤더/카운트다운/옵션 사이 separator 공통)
        static let separatorHorizontalInset: CGFloat = 14

        /// 패널 최하단 여백(QuickTimer 아래)
        static let panelBottomSpacing: CGFloat = 8

        /// 옵션 섹션 사이 separator 위아래 여백
        static let optionsInnerSeparatorVerticalPadding: CGFloat = 2

        /// 푸터 크레딧 행 상하 padding
        ///
        /// 11pt 텍스트 기준 위아래 7pt면 행 높이가 약 25pt가 되어 옵션 행(rowPaddingVertical 7)과
        /// 시각적으로 동일한 리듬을 갖는다. QuickTimer 그리드 아래에 자연스럽게 합류하도록
        /// `panelBottomSpacing`(8)이 그대로 적용되는 위치에 둔다
        static let footerPaddingVertical: CGFloat = 7

        /// 카운트다운 영역 고정 높이
        ///
        /// 텍스트 18pt + 상하 padding(8 + 6) 합산 기준으로 32pt를 사용한다.
        /// 카운트다운 길이가 시:분:초 vs 분:초로 바뀌어도 부모 layout이 흔들리지 않게 한다
        static let countdownHeight: CGFloat = 32

        /// 옵션 섹션 라벨 좌우 padding(들여쓰기 적용)
        ///
        /// 잠자기 방지/앱 설정 섹션 라벨은 같은 섹션의 행보다 들여쓴 위치에 둔다.
        /// `sectionLabelPaddingHorizontal`(10) + 추가 들여쓰기 8pt = 18pt
        static let sectionLabelPaddingHorizontalIndented: CGFloat = 18

        /// QuickTimer 헤더 좌우 padding
        ///
        /// 사용자 지정 입력 모드에서 헤더 텍스트와 동일한 좌우 정렬을 위해 헤더와 같은 18pt를 쓴다
        static let quickTimerHeaderPaddingHorizontal: CGFloat = 18

        /// QuickTimer 사용자 지정 모드 진입 시 상단 여백
        static let quickTimerCustomPaddingTop: CGFloat = 16

        /// QuickTimer 그리드 모드 상단 여백
        static let quickTimerGridPaddingTop: CGFloat = 4

        /// QuickTimer 섹션 하단 여백
        static let quickTimerSectionPaddingBottom: CGFloat = 4

        /// QuickTimer LazyVGrid 외곽 vertical padding
        static let quickTimerGridOuterPaddingVertical: CGFloat = 2

        /// QuickTimer 사용자 지정 헤더와 입력 행 사이 간격
        static let customInputHeaderPaddingBottom: CGFloat = 16

        /// QuickTimer 사용자 지정 입력 행 hstack 내부 spacing
        static let customInputFieldSpacing: CGFloat = 10

        /// QuickTimer 사용자 지정 콜론 글리프 하단 padding(베이스라인 정렬용)
        static let customColonPaddingBottom: CGFloat = 20

        /// QuickTimer 사용자 지정 액션 버튼 상단 padding
        static let customActionsPaddingTop: CGFloat = 20

        /// QuickTimer 사용자 지정 액션 버튼 사이 spacing
        static let customActionsSpacing: CGFloat = 8

        /// QuickTimer 사용자 지정 입력 박스 폭
        static let customInputFieldWidth: CGFloat = 64

        /// QuickTimer 사용자 지정 입력 박스 padding
        static let customInputFieldPaddingHorizontal: CGFloat = 4
        static let customInputFieldPaddingVertical: CGFloat = 10
        static let customInputLabelSpacing: CGFloat = 6

        /// QuickTimer 액션 버튼 vertical padding
        static let customActionButtonPaddingVertical: CGFloat = 6

        /// 옵션 행 텍스트와 우측 컨트롤 사이 간격
        static let rowContentSpacing: CGFloat = 12

        /// 옵션 라벨과 플래그 뱃지 사이 간격
        static let rowLabelFlagSpacing: CGFloat = 6

        /// 옵션 라벨 1차/2차 텍스트 사이 간격
        static let rowLabelStackSpacing: CGFloat = 2

        /// 플래그 뱃지 padding
        static let flagBadgePaddingHorizontal: CGFloat = 6
        static let flagBadgePaddingVertical: CGFloat = 1

        /// 헤더 타이틀 + 상태 텍스트 사이 간격(v3 명세 4pt)
        static let headerTitleStatusSpacing: CGFloat = 4

        /// 언어 segmented control 칩 사이 spacing
        static let languageSegmentsSpacing: CGFloat = 4

        /// 언어 segmented control 외곽 padding
        static let languageSegmentsOuterPadding: CGFloat = 2

        /// 언어 segmented control 칩 padding
        static let languageSegmentChipPaddingHorizontal: CGFloat = 10
        static let languageSegmentChipPaddingVertical: CGFloat = 4

        /// 토글 트랙 폭. v3 명세 40pt
        static let toggleTrackWidth: CGFloat = 40

        /// 토글 트랙 높이. v3 명세 22pt
        static let toggleTrackHeight: CGFloat = 22

        /// 토글 knob 지름. v3 명세 18pt
        static let toggleKnobDiameter: CGFloat = 18

        /// 토글 knob ON 좌측 inset(트랙 좌측 기준). v3 명세 19pt
        static let toggleKnobOnLeftInset: CGFloat = 19

        /// 토글 knob OFF 좌측 inset(트랙 좌측 기준). v3 명세 1.5pt
        static let toggleKnobOffLeftInset: CGFloat = 1.5
    }

    enum Typography {

        /// "Caffeine" 헤더 타이틀. v3 명세 15pt semibold
        static let headerTitle = Font.system(size: 15, weight: .semibold)

        /// 헤더 상태 텍스트. v3 명세 11pt medium
        static let headerStatus = Font.system(size: 11, weight: .medium)

        /// 카운트다운. v3 명세 18pt semibold monospaced
        static let countdown = Font.system(size: 18, weight: .semibold, design: .monospaced)

        /// "남음" 라벨. v3 명세 12pt medium
        static let countdownLabel = Font.system(size: 12, weight: .medium)

        /// 섹션 라벨(QUICK TIMER, OPTIONS). 11pt medium uppercase
        static let sectionLabel = Font.system(size: 11, weight: .medium)

        /// 칩 텍스트. 12pt medium
        static let chip = Font.system(size: 12, weight: .medium)

        /// 옵션 라벨. v3 명세 13pt
        static let optionLabel = Font.system(size: 13, weight: .regular)

        /// 옵션 설명(2차 라인). v3 명세 12pt fg-tertiary line-height 1.4
        static let optionDesc = Font.system(size: 12, weight: .regular)

        /// CLI 플래그 뱃지. v3 명세 10pt monospaced medium
        static let flagBadge = Font.system(size: 10, weight: .medium, design: .monospaced)

        /// 사용자 지정 타이머 입력 박스 숫자. v3 명세 28pt semibold
        static let customNumberInput = Font.system(size: 28, weight: .semibold)

        /// 사용자 지정 타이머 헤더. 13pt medium
        static let customHeader = Font.system(size: 13, weight: .medium)

        /// 사용자 지정 콜론 글리프. 28pt bold
        static let customColon = Font.system(size: 28, weight: .bold)

        /// 사용자 지정 입력 라벨(시간/분). 10pt medium
        static let customInputLabel = Font.system(size: 10, weight: .medium)

        /// 취소/시작 버튼. 12pt medium
        static let actionButton = Font.system(size: 12, weight: .medium)

        /// 푸터 크레딧(GitHub 핸들). 11pt regular
        ///
        /// 섹션 라벨(`sectionLabel`, 11pt medium)과 같은 사이즈지만 weight를 한 단계 낮춰
        /// 시각적 위계상 가장 약한 신호로 둔다(`fg-tertiary` 컬러 적용 시 가독성 확보)
        static let footerCredit = Font.system(size: 11, weight: .regular)
    }

    enum Motion {

        /// 토글 200ms spring 근사값
        ///
        /// v3 명세는 `cubic-bezier(0.34, 1.56, 0.64, 1)` 오버슛 spring이지만 NSPanel 자동
        /// 리사이즈 사이클과 충돌해 무한 재귀 사례가 있어 가벼운 spring으로 근사한다.
        /// 카운트다운 매초 재렌더링과 합쳐졌을 때 잔여 오버슛이 시각적으로 흔들림으로
        /// 인식되던 회귀를 막기 위해 dampingFraction을 0.92까지 올려 정착 시 진동을
        /// 0에 가깝게 만든다(`response: 0.20`)
        static let toggleSpring = Animation.spring(response: 0.20, dampingFraction: 0.92, blendDuration: 0)

        /// hover 트랜지션. v3 명세 120ms easeOut
        static let hover = Animation.easeOut(duration: 0.12)

        /// 일반 트랜지션. v3 명세 200ms cubic-bezier(0.25, 1, 0.5, 1) 근사
        static let standard = Animation.easeOut(duration: 0.2)
    }
}

extension Color {

    /// 0xRRGGBB 정수 hex로 색상을 만든다
    ///
    /// SwiftUI 기본에 16진 이니셜라이저가 없어 자체 추가한다
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: 1.0
        )
    }
}
