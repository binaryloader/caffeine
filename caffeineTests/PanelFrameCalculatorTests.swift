//
//  PanelFrameCalculatorTests.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit
import XCTest
@testable import caffeine

/// `PanelFrameCalculator`의 산식과 클램프 동작 검증
///
/// AppKit 객체 의존을 빼고 NSRect 기반으로 산식을 검증할 수 있도록 추가된 internal 오버로드
/// (`calculate(fittingSize:statusItemButtonScreenFrame:visibleScreenFrame:)`)를 사용한다.
/// 메인 디스플레이/회전 화면/Dock 위치/외장 디스플레이 등 다양한 가상 시나리오에서 클램프 결과를
/// 잠근다
final class PanelFrameCalculatorTests: XCTestCase {

    // MARK: - 헬퍼

    /// 표준 calculator + 메인 디스플레이 가정. 단순 케이스에 사용
    @MainActor
    private func makeStandard() -> PanelFrameCalculator {
        PanelFrameCalculator.standard
    }

    /// macOS 메인 디스플레이의 일반적인 좌표(원점 0,0, visibleFrame y는 메뉴바/Dock 뺀 영역).
    /// macOS는 좌측 하단이 원점이고 메뉴바는 화면 상단에 위치한다
    /// - 가정: 1920x1080 화면, 메뉴바 24pt, Dock 없음
    private static let typicalVisibleFrame = NSRect(x: 0, y: 0, width: 1920, height: 1056)

    /// 메뉴바 statusItem 버튼이 메뉴바 우측에 위치한 경우의 화면 좌표
    /// - macOS 메뉴바는 visibleFrame 위에 위치하므로 minY = visibleFrame.maxY = 1056
    /// - 메뉴바 높이 24pt이므로 height = 24
    /// - 우측 끝 가까이(예: x = 1700, width = 22)
    private static let typicalMenuBarButtonRect = NSRect(x: 1700, y: 1056, width: 22, height: 24)

    // MARK: - standard 인스턴스 sanity

    @MainActor
    func test_standard_파라미터가_핸드오프_명세와_일치한다() {
        let calc = PanelFrameCalculator.standard
        XCTAssertEqual(calc.panelTopGap, 6)
        XCTAssertEqual(calc.panelBottomMargin, 8)
        XCTAssertEqual(calc.panelEdgePadding, 8)
        XCTAssertEqual(calc.panelMinHeight, 200)
        XCTAssertEqual(calc.panelMinWidth, DesignTokens.Layout.windowWidth)
    }

    // MARK: - Calculated Equatable

    func test_Calculated는_panelFrame과_hostingFrame이_같으면_동등하다() {
        let a = PanelFrameCalculator.Calculated(
            panelFrame: NSRect(x: 0, y: 0, width: 100, height: 200),
            hostingFrame: NSRect(x: 0, y: 0, width: 100, height: 200)
        )
        let b = PanelFrameCalculator.Calculated(
            panelFrame: NSRect(x: 0, y: 0, width: 100, height: 200),
            hostingFrame: NSRect(x: 0, y: 0, width: 100, height: 200)
        )
        XCTAssertEqual(a, b)
    }

    func test_Calculated는_panelFrame이_다르면_같지_않다() {
        let a = PanelFrameCalculator.Calculated(
            panelFrame: NSRect(x: 0, y: 0, width: 100, height: 200),
            hostingFrame: NSRect(x: 0, y: 0, width: 100, height: 200)
        )
        let b = PanelFrameCalculator.Calculated(
            panelFrame: NSRect(x: 1, y: 0, width: 100, height: 200),
            hostingFrame: NSRect(x: 0, y: 0, width: 100, height: 200)
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - 메인 디스플레이 일반 케이스

    @MainActor
    func test_일반적인_메인_디스플레이_케이스는_메뉴바_아래에_topGap만큼_띄워_정렬한다() {
        let calc = makeStandard()
        let fittingSize = NSSize(width: 380, height: 400)
        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: Self.typicalMenuBarButtonRect,
            visibleScreenFrame: Self.typicalVisibleFrame
        )

        // 너비는 fittingSize.width(380)와 panelMinWidth 중 큰 값. 380이 panelMinWidth와 같다
        XCTAssertEqual(result.panelFrame.width, max(380, calc.panelMinWidth))
        // 높이는 fittingSize.height(400)와 가용 높이 중 작은 값. 가용 높이가 충분하므로 400 그대로
        XCTAssertEqual(result.panelFrame.height, 400)
        // Y는 메뉴바 minY(1056)에서 height(400) + topGap(6) 뺀 값 = 650
        XCTAssertEqual(result.panelFrame.minY, 1056 - 400 - 6)
    }

    @MainActor
    func test_X는_메뉴바_버튼_중앙을_기준으로_정렬된다() {
        let calc = makeStandard()
        let fittingSize = NSSize(width: 380, height: 300)
        // 버튼 중앙: x = 1700 + 22/2 = 1711
        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: Self.typicalMenuBarButtonRect,
            visibleScreenFrame: Self.typicalVisibleFrame
        )

        // 중앙 정렬 후 visibleFrame 안쪽 클램프(maxX = 1920 - 380 - 8 = 1532)
        // 1711 - 380/2 = 1521. 이 값은 maxX(1532)보다 작아 그대로 사용됨
        XCTAssertEqual(result.panelFrame.minX, 1521)
    }

    // MARK: - X 우측 경계 클램프

    @MainActor
    func test_버튼이_우측_끝에_있으면_panel은_visibleFrame_우측에서_edgePadding만큼_떨어진_위치로_클램프된다() {
        let calc = makeStandard()
        let fittingSize = NSSize(width: 380, height: 300)
        // 버튼이 거의 우측 끝(예: 1900~1920)에 위치
        let buttonRect = NSRect(x: 1900, y: 1056, width: 20, height: 24)
        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: buttonRect,
            visibleScreenFrame: Self.typicalVisibleFrame
        )

        // 중앙 정렬 시 minX = 1910 - 190 = 1720, 클램프 maxX = 1920 - 380 - 8 = 1532
        XCTAssertEqual(result.panelFrame.minX, 1532)
    }

    // MARK: - X 좌측 경계 클램프

    @MainActor
    func test_버튼이_좌측_끝에_있으면_panel은_visibleFrame_좌측에서_edgePadding만큼_떨어진_위치로_클램프된다() {
        let calc = makeStandard()
        let fittingSize = NSSize(width: 380, height: 300)
        // 버튼이 좌측 끝 근처
        let buttonRect = NSRect(x: 4, y: 1056, width: 22, height: 24)
        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: buttonRect,
            visibleScreenFrame: Self.typicalVisibleFrame
        )

        // 중앙 정렬 시 minX = 15 - 190 = -175, 클램프 minX = 0 + 8 = 8
        XCTAssertEqual(result.panelFrame.minX, 8)
    }

    // MARK: - Y 클램프 (작은 화면)

    @MainActor
    func test_visibleFrame이_panelMinHeight보다_작으면_height가_가용_영역으로_클램프된다() {
        let calc = makeStandard()
        // 매우 작은 화면 가정: 800x300, visibleFrame.height = 280
        let smallVisible = NSRect(x: 0, y: 0, width: 800, height: 280)
        let buttonRect = NSRect(x: 700, y: 280, width: 22, height: 24)
        let fittingSize = NSSize(width: 380, height: 600)

        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: buttonRect,
            visibleScreenFrame: smallVisible
        )

        // 가용 높이 = buttonY(280) - visibleMinY(0) - topGap(6) - bottomMargin(8) = 266
        // visibleHeightCap = 280 - 6 - 8 = 266
        // cappedMinHeight = min(200, max(266, 0)) = 200
        // safeMaxHeight = max(266, 200) = 266
        // 결과: 600을 266으로 클램프
        XCTAssertEqual(result.panelFrame.height, 266)
    }

    @MainActor
    func test_콘텐츠가_가용_높이보다_작으면_콘텐츠_높이를_그대로_사용한다() {
        let calc = makeStandard()
        let fittingSize = NSSize(width: 380, height: 220)
        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: Self.typicalMenuBarButtonRect,
            visibleScreenFrame: Self.typicalVisibleFrame
        )

        XCTAssertEqual(result.panelFrame.height, 220)
    }

    // MARK: - panelMinWidth 보강

    @MainActor
    func test_fittingSize_width가_panelMinWidth보다_작으면_panelMinWidth로_보강된다() {
        let calc = makeStandard()
        // 비정상적으로 좁은 콘텐츠
        let fittingSize = NSSize(width: 200, height: 300)
        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: Self.typicalMenuBarButtonRect,
            visibleScreenFrame: Self.typicalVisibleFrame
        )

        XCTAssertEqual(result.panelFrame.width, calc.panelMinWidth)
    }

    // MARK: - hostingFrame 산식

    @MainActor
    func test_hostingFrame은_origin이_zero이고_panel_width와_콘텐츠_height를_가진다() {
        let calc = makeStandard()
        let fittingSize = NSSize(width: 400, height: 350)
        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: Self.typicalMenuBarButtonRect,
            visibleScreenFrame: Self.typicalVisibleFrame
        )

        XCTAssertEqual(result.hostingFrame.origin, .zero)
        XCTAssertEqual(result.hostingFrame.width, 400)
        // hostingFrame.height는 panel이 콘텐츠보다 작을 때도 콘텐츠 height 그대로(헤더 보존)
        XCTAssertEqual(result.hostingFrame.height, 350)
    }

    @MainActor
    func test_콘텐츠가_화면보다_커도_hostingFrame은_콘텐츠_height를_그대로_유지한다() {
        let calc = makeStandard()
        // 가용 높이가 작은 화면
        let smallVisible = NSRect(x: 0, y: 0, width: 800, height: 300)
        let buttonRect = NSRect(x: 700, y: 300, width: 22, height: 24)
        let fittingSize = NSSize(width: 380, height: 700)

        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: buttonRect,
            visibleScreenFrame: smallVisible
        )

        // panel.height는 클램프되지만 hosting.height는 콘텐츠 700 그대로
        XCTAssertLessThan(result.panelFrame.height, 700)
        XCTAssertEqual(result.hostingFrame.height, 700)
    }

    // MARK: - 외장 디스플레이/회전 가상 시나리오

    @MainActor
    func test_외장_디스플레이는_visibleFrame_origin이_0이_아닌_경우에도_정상_정렬한다() {
        let calc = makeStandard()
        // 메인 디스플레이 우측에 외장 디스플레이가 있다고 가정. 외장 origin x = 1920
        let externalVisible = NSRect(x: 1920, y: 0, width: 2560, height: 1416)
        let externalButton = NSRect(x: 4400, y: 1416, width: 22, height: 24)
        let fittingSize = NSSize(width: 380, height: 400)

        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: externalButton,
            visibleScreenFrame: externalVisible
        )

        // 외장 디스플레이 영역 안에 있어야 한다(좌측 경계 1920 + 8 = 1928 이상)
        XCTAssertGreaterThanOrEqual(result.panelFrame.minX, 1928)
        // 외장 디스플레이 우측 경계 안쪽
        XCTAssertLessThanOrEqual(result.panelFrame.maxX, 1920 + 2560 - 8)
        // Y 정렬은 메뉴바 아래 topGap(6)만큼
        XCTAssertEqual(result.panelFrame.minY, 1416 - 400 - 6)
    }

    @MainActor
    func test_세로_회전_디스플레이에서도_topGap과_bottomMargin이_유지된다() {
        let calc = makeStandard()
        // 회전된 외장(세로) 디스플레이: 1080x1920, visibleFrame.height = 1896
        let rotatedVisible = NSRect(x: 0, y: 0, width: 1080, height: 1896)
        let rotatedButton = NSRect(x: 1000, y: 1896, width: 22, height: 24)
        let fittingSize = NSSize(width: 380, height: 600)

        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: rotatedButton,
            visibleScreenFrame: rotatedVisible
        )

        // panel은 visibleFrame 안쪽
        XCTAssertGreaterThanOrEqual(result.panelFrame.minY, rotatedVisible.minY + calc.panelBottomMargin)
        XCTAssertLessThanOrEqual(result.panelFrame.maxY, rotatedButton.minY - calc.panelTopGap)
    }

    @MainActor
    func test_Dock이_좌측에_있어_visibleFrame_origin_x가_0이_아닌_케이스에서도_좌측_클램프가_정상_동작한다() {
        let calc = makeStandard()
        // Dock 좌측 위치 시뮬레이션: visibleFrame.minX = 80
        let visibleWithLeftDock = NSRect(x: 80, y: 0, width: 1840, height: 1056)
        // 버튼이 visibleFrame 좌측 가까이 있는 경우
        let leftButton = NSRect(x: 90, y: 1056, width: 22, height: 24)
        let fittingSize = NSSize(width: 380, height: 300)

        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: leftButton,
            visibleScreenFrame: visibleWithLeftDock
        )

        // 좌측 경계는 visibleFrame.minX(80) + edgePadding(8) = 88
        XCTAssertEqual(result.panelFrame.minX, 88)
    }

    @MainActor
    func test_visibleFrame이_panelTopGap_bottomMargin_합보다_작은_극단_케이스에서도_노옵하지_않는다() {
        let calc = makeStandard()
        // visibleFrame.height = 10. panelTopGap(6) + panelBottomMargin(8) = 14, 즉 음수가 됨
        let tinyVisible = NSRect(x: 0, y: 0, width: 800, height: 10)
        let tinyButton = NSRect(x: 700, y: 10, width: 22, height: 24)
        let fittingSize = NSSize(width: 380, height: 600)

        let result = calc.calculate(
            fittingSize: fittingSize,
            statusItemButtonScreenFrame: tinyButton,
            visibleScreenFrame: tinyVisible
        )

        // 클램프된 height가 음수로 가지 않고 0 이상이어야 한다(visibleHeightCap을 max(_, 0)로 보호)
        XCTAssertGreaterThanOrEqual(result.panelFrame.height, 0)
    }

    // MARK: - statusItemButton 없는 환경 가드

    @MainActor
    func test_calculator_시그니처는_standard_프로퍼티를_노출한다() {
        // 컴파일 타임 시그니처 가드. 미래 리네이밍 사고 방지
        let _: CGFloat = PanelFrameCalculator.standard.panelTopGap
        let _: CGFloat = PanelFrameCalculator.standard.panelBottomMargin
        let _: CGFloat = PanelFrameCalculator.standard.panelEdgePadding
        let _: CGFloat = PanelFrameCalculator.standard.panelMinHeight
        let _: CGFloat = PanelFrameCalculator.standard.panelMinWidth
    }
}
