//
//  PanelFrameCalculator.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit

/// 메뉴바 statusItem 아래에 위치할 NSPanel의 frame을 계산하는 순수 함수 모음
///
/// 핵심 동작은 아래와 같다
/// - statusItem 버튼의 화면 좌표(`buttonScreenFrame`)와 화면 가용 영역(`visibleFrame`)을 구한다
/// - 가용 최대 높이 = 메뉴바 아래부터 화면 하단(`bottomMargin` 제외)까지로 정의한다
/// - 콘텐츠 fittingSize.height가 가용 최대 높이를 넘으면 가용 높이로 클램프한다
/// - X는 메뉴바 버튼 중앙을 기준으로 좌우 `edgePadding` 안쪽으로 클램프한다
/// - Y는 메뉴바 버튼 아래(`panelTopGap`)에 고정하되 `visibleFrame.minY` 아래로 내려가지 않게 한다
/// - 외장 디스플레이 회전/Dock 위치 등 극단 케이스에서 panelMinHeight이 visibleFrame을 초과하면
///   패널이 화면 밖으로 잘릴 수 있다. visibleFrame.height에서 상하 여백을 뺀 값을
///   panelMinHeight 상한으로 둬서 작은 화면에서도 보이는 만큼만 확보한다
@MainActor
struct PanelFrameCalculator {

    /// statusItem 버튼 아래 정렬 시 추가 vertical 여백(메뉴바와 패널 사이 간격)
    let panelTopGap: CGFloat

    /// 화면 바닥과 패널 사이 최소 여백
    let panelBottomMargin: CGFloat

    /// 화면 좌우 가장자리와 패널 사이 최소 여백
    let panelEdgePadding: CGFloat

    /// 가용 영역이 비정상적으로 작을 때라도 보장할 최소 패널 높이
    let panelMinHeight: CGFloat

    /// 패널 최소 너비
    let panelMinWidth: CGFloat

    /// 기본 layout 상수로 초기화한다
    static let standard = PanelFrameCalculator(
        panelTopGap: 6,
        panelBottomMargin: 8,
        panelEdgePadding: 8,
        panelMinHeight: 200,
        panelMinWidth: DesignTokens.Layout.windowWidth
    )

    /// fittingSize와 statusItem 버튼 위치를 받아 적용할 패널 frame을 계산한다
    ///
    /// 호출 측은 buttonWindow가 nil이면 panel을 표시할 수 없으므로 result를 nil로 받아 노옵으로 처리한다.
    /// 이 메서드는 AppKit 객체에서 좌표만 추출한 뒤 NSRect 기반 오버로드(`calculate(fittingSize:statusItemButtonScreenFrame:visibleScreenFrame:)`)에
    /// 위임한다. 산식 자체는 NSRect 오버로드에서 단위 테스트 가능한 형태로 분리되어 있다
    func calculate(
        fittingSize: NSSize,
        statusItemButton: NSStatusBarButton
    ) -> Calculated? {
        guard let buttonWindow = statusItemButton.window else { return nil }

        let buttonFrame = statusItemButton.convert(statusItemButton.bounds, to: nil)
        let buttonScreenFrame = buttonWindow.convertToScreen(buttonFrame)
        let screen = buttonWindow.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? buttonScreenFrame

        return calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: buttonScreenFrame,
            visibleScreenFrame: visibleFrame
        )
    }

    /// 산식 본체. AppKit 의존 없이 NSRect 두 개만 받아 결정적으로 panel/hosting frame을 만든다
    ///
    /// 단위 테스트는 이 시그니처를 직접 호출해 외장 디스플레이/회전/Dock 위치 등 다양한 가상
    /// 시나리오를 검증한다. NSStatusBarButton을 인스턴스화하기 어려운 환경에서도 산식 회귀를
    /// 잠글 수 있다
    func calculate(
        fittingSize: NSSize,
        statusItemButtonScreenFrame buttonScreenFrame: NSRect,
        visibleScreenFrame visibleFrame: NSRect
    ) -> Calculated {
        let width = max(fittingSize.width, panelMinWidth)

        // 메뉴바 아래에서 화면 바닥까지 사용 가능한 세로 공간
        let maxAvailableHeight =
            buttonScreenFrame.minY
            - visibleFrame.minY
            - panelTopGap
            - panelBottomMargin
        // 외장 디스플레이 회전/Dock 위치 등 극단 케이스에서 panelMinHeight이 visibleFrame을 초과하면
        // 패널이 화면 밖으로 잘릴 수 있다. visibleFrame.height에서 상하 여백을 뺀 값을
        // panelMinHeight 상한으로 둬서 작은 화면에서도 보이는 만큼만 확보한다
        let visibleHeightCap =
            visibleFrame.height
            - panelTopGap
            - panelBottomMargin
        let cappedMinHeight = min(panelMinHeight, max(visibleHeightCap, 0))
        let safeMaxHeight = max(maxAvailableHeight, cappedMinHeight)
        let height = min(max(fittingSize.height, 1), safeMaxHeight)

        // X: 메뉴바 버튼 중앙 정렬 후 visibleFrame 안쪽으로 클램프
        var originX = buttonScreenFrame.midX - width / 2
        let minX = visibleFrame.minX + panelEdgePadding
        let maxX = visibleFrame.maxX - width - panelEdgePadding
        if maxX > minX {
            originX = min(max(originX, minX), maxX)
        } else {
            originX = minX
        }

        // Y: 메뉴바 버튼 바로 아래에서 height만큼 내린 origin
        var originY = buttonScreenFrame.minY - height - panelTopGap
        // visibleFrame.minY 아래로는 절대 내려가지 않도록 한 번 더 클램프
        let minOriginY = visibleFrame.minY + panelBottomMargin
        if originY < minOriginY {
            originY = minOriginY
        }

        let panelFrame = NSRect(
            x: originX,
            y: originY,
            width: width,
            height: height
        )

        // 호스팅 뷰는 fittingSize 그대로 둔다. flipped 컨테이너 위에 상단(y = 0) 정렬되어
        // 패널이 콘텐츠보다 작아도 헤더가 잘리지 않고 하단만 잘린다
        let hostingHeight = max(fittingSize.height, 1)
        let hostingFrame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: hostingHeight
        )

        return Calculated(panelFrame: panelFrame, hostingFrame: hostingFrame)
    }

    /// 계산 결과
    struct Calculated: Equatable {
        let panelFrame: NSRect
        let hostingFrame: NSRect
    }
}
