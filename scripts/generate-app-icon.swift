#!/usr/bin/env swift
//
//  generate-app-icon.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

// 앱 아이콘 1024x1024 PNG를 한 번에 생성하는 수동 스크립트
//
// macOS는 시스템이 자동으로 라운드 사각 마스킹을 적용하므로 PNG는 정사각형 + 약 10%
// safe inset을 둔다. 디자인 컨셉은 다음과 같다
// - 배경: 짙은 회색 → 검정 대각 그라디언트(좌상→우하). 패널 글래스와 같은 톤 패밀리
// - 중앙: 따뜻한 호박색 라인 일러스트 머그(컵만, 김 없음)
// - 컵 입구는 위쪽, 손잡이는 우측 D자형
// - stroke 위주 미니멀 룩
//
// 좌표계: NSImage.lockFocus()(flipped 아님)로 y-up Cocoa 좌표계 사용
// - origin (0, 0)은 좌하단
// - y가 클수록 위쪽
// - 따라서 컵 입구의 y(cupTopY)는 컵 바닥의 y(cupBottomY)보다 크다
//
// 실행: swift /path/to/generate-app-icon.swift /path/to/Assets.xcassets/AppIcon.appiconset
// 1024 PNG를 쓰고 sips로 16/32/64/128/256/512 (1x/2x) PNG를 같은 디렉토리에 덮어쓴다

import AppKit
import CoreGraphics
import Foundation

// MARK: - Color helpers

func color(
    _ hex: UInt32,
    alpha: CGFloat = 1
) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255

    return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

// MARK: - Drawing

let canvasSize: CGFloat = 1024
let safeInset: CGFloat = 96  // 약 9.4%

// 픽셀 단위로 정확히 1024x1024 비트맵에 직접 그린다
// NSImage의 lockFocus는 backing scale factor에 따라 자동 @2x가 적용되어
// 결과물이 2048x2048이 될 수 있다. 이를 피하기 위해 NSBitmapImageRep에 직접 그린다
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize),
    pixelsHigh: Int(canvasSize),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("Failed to create bitmap\n".utf8))
    exit(1)
}

guard let bitmapContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("Failed to create graphics context\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = bitmapContext

guard let context = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write(Data("CGContext not available\n".utf8))
    exit(1)
}

let canvasRect = CGRect(
    x: 0,
    y: 0,
    width: canvasSize,
    height: canvasSize
)

// 배경: 짙은 회색에서 검정으로 떨어지는 대각 그라디언트(좌상→우하)
// y-up 좌표계에서 좌상단은 (0, canvasSize), 우하단은 (canvasSize, 0)
let backgroundColors = [
    color(0x2A2A30).cgColor,
    color(0x0E0E12).cgColor
] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: backgroundColors,
    locations: [0.0, 1.0]
) else {
    FileHandle.standardError.write(Data("Failed to create gradient\n".utf8))
    exit(1)
}

context.saveGState()
context.addRect(canvasRect)
context.clip()
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: canvasSize),
    end: CGPoint(x: canvasSize, y: 0),
    options: []
)
context.restoreGState()

// 머그는 안전 영역 안에서 그린다
let safeRect = canvasRect.insetBy(dx: safeInset, dy: safeInset)

// 호박색 stroke
let amber = color(0xE0A868)

// 컵 본체와 손잡이를 격리된 GState에서 그린다
context.saveGState()

context.setStrokeColor(amber.cgColor)
context.setLineCap(.round)
context.setLineJoin(.round)

let mugLineWidth: CGFloat = 26
context.setLineWidth(mugLineWidth)

// 컵 영역 정의(y-up: top y > bottom y)
// 컵 본체 가로 폭은 안전 영역의 약 50%, 손잡이가 우측에 추가로 약 16% 돌출
// 컵 본체의 중앙 자체를 캔버스 중앙에 정렬한다. 손잡이는 우측으로 더 나가지만
// 시각 무게중심인 본체가 정중앙에 있어야 사람이 가운데 있다고 인식한다
let cupBodyWidth = safeRect.width * 0.50
let handleWidth = safeRect.width * 0.16
let cupBodyHeight = safeRect.height * 0.62

// 컵 본체 중심 = 캔버스(safeRect) 중앙
let cupLeft = safeRect.midX - cupBodyWidth / 2
let cupRight = safeRect.midX + cupBodyWidth / 2

// 손잡이 끝(cupRight + handleWidth)이 safeRect 우측 경계 이내인지 검증
// 라인 두께(mugLineWidth/2)도 고려한다
assert(
    cupRight + handleWidth + mugLineWidth / 2 <= safeRect.maxX,
    "Handle exceeds safe area"
)

// y 정렬: 컵 전체 bounding box(stroke 두께와 바닥 라운드 최저점 포함)의 시각 무게중심을
// safeRect.midY와 일치시킨다.
//
// 시각 상단 = cupTopY(입구 가로선 중심) + mugLineWidth/2
// 시각 하단 = bottomCurveLowestY - mugLineWidth/2
//
// 바닥은 quadratic Bezier로 그려지며 좌/우 끝점은 (x, cupBottomY + bottomEndpointInset),
// control point는 (midX, cupBottomY - bottomControlDip)이다.
// y축 대칭 quad bezier의 t=0.5 지점 y = 0.5*endpointY + 0.5*controlY
// = 0.5*(cupBottomY + bottomEndpointInset) + 0.5*(cupBottomY - bottomControlDip)
// = cupBottomY + (bottomEndpointInset - bottomControlDip)/2
// 이것이 곡선의 시각 최저 중심이다(stroke 두께를 빼야 진짜 최저).
let bottomEndpointInset: CGFloat = 36
let bottomControlDip: CGFloat = 30
let bottomCurveCenterOffset: CGFloat = (bottomEndpointInset - bottomControlDip) / 2

// 시각적 컵 높이 = (cupTopY + mugLineWidth/2) - (cupBottomY + bottomCurveCenterOffset - mugLineWidth/2)
//               = (cupTopY - cupBottomY) + mugLineWidth - bottomCurveCenterOffset
//               = cupBodyHeight + mugLineWidth - bottomCurveCenterOffset
// 이 높이의 중심을 safeRect.midY에 두려면
//   cupTopY + mugLineWidth/2 + cupBottomY + bottomCurveCenterOffset - mugLineWidth/2
//     = 2 * safeRect.midY
//   (cupTopY + cupBottomY) + bottomCurveCenterOffset = 2 * safeRect.midY
//   cupTopY + cupBottomY = 2 * safeRect.midY - bottomCurveCenterOffset
//
// cupTopY - cupBottomY = cupBodyHeight 를 함께 풀면
//   cupTopY    = safeRect.midY + cupBodyHeight/2 - bottomCurveCenterOffset/2
//   cupBottomY = safeRect.midY - cupBodyHeight/2 - bottomCurveCenterOffset/2
let cupTopY = safeRect.midY + cupBodyHeight / 2 - bottomCurveCenterOffset / 2
let cupBottomY = safeRect.midY - cupBodyHeight / 2 - bottomCurveCenterOffset / 2

// 컵 본체 외곽: 좌측 입구 → 좌측 벽 아래 → 둥근 바닥 → 우측 벽 위 → 우측 입구
// 컵 입구(상단)는 약간 더 넓은 사다리꼴, 바닥은 라운드 처리
let cupBodyPath = CGMutablePath()

// 좌측 입구(top-left)
cupBodyPath.move(to: CGPoint(x: cupLeft, y: cupTopY))
// 좌측 벽 아래로
cupBodyPath.addLine(to: CGPoint(x: cupLeft + 18, y: cupBottomY + bottomEndpointInset))
// 라운드 바닥(좌하 → 우하)
cupBodyPath.addQuadCurve(
    to: CGPoint(x: cupRight - 18, y: cupBottomY + bottomEndpointInset),
    control: CGPoint(x: (cupLeft + cupRight) / 2, y: cupBottomY - bottomControlDip)
)
// 우측 벽 위로
cupBodyPath.addLine(to: CGPoint(x: cupRight, y: cupTopY))

context.addPath(cupBodyPath)
context.strokePath()

// 컵 입구(상단 가로선)
context.setLineWidth(mugLineWidth)
context.move(to: CGPoint(x: cupLeft - 10, y: cupTopY))
context.addLine(to: CGPoint(x: cupRight + 10, y: cupTopY))
context.strokePath()

// 손잡이(우측 D자형) - 컵 우측 벽 중간 부분에서 시작/끝
let handleTopY = cupTopY - cupBodyHeight * 0.18
let handleBottomY = cupBottomY + cupBodyHeight * 0.22
let handlePeakX = cupRight + handleWidth

let handlePath = CGMutablePath()
handlePath.move(to: CGPoint(x: cupRight + 6, y: handleTopY))
handlePath.addCurve(
    to: CGPoint(x: cupRight + 6, y: handleBottomY),
    control1: CGPoint(x: handlePeakX, y: handleTopY),
    control2: CGPoint(x: handlePeakX, y: handleBottomY)
)
context.addPath(handlePath)
context.strokePath()

context.restoreGState()

NSGraphicsContext.restoreGraphicsState()

// MARK: - PNG export

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to encode PNG\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: generate-app-icon.swift <AppIcon.appiconset path>\n".utf8))
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1])
let icon1024URL = outputDirectory.appendingPathComponent("icon_1024.png")

do {
    try pngData.write(to: icon1024URL)
    print("Wrote \(icon1024URL.path)")
} catch {
    FileHandle.standardError.write(Data("Failed to write PNG: \(error)\n".utf8))
    exit(1)
}

// MARK: - Resize to all required slot sizes via sips

// Contents.json은 16/32/64/128/256/512/1024 PNG를 각 슬롯에 매핑한다
// 1024를 마스터로 두고 sips로 리사이즈하여 같은 디렉토리에 덮어쓴다
let resizeTargets: [Int] = [16, 32, 64, 128, 256, 512]

for size in resizeTargets {
    let outputURL = outputDirectory.appendingPathComponent("icon_\(size).png")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = [
        "-z",
        String(size),
        String(size),
        icon1024URL.path,
        "--out",
        outputURL.path
    ]
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            FileHandle.standardError.write(Data("sips failed for size \(size)\n".utf8))
            exit(1)
        }

        print("Wrote \(outputURL.path)")
    } catch {
        FileHandle.standardError.write(Data("Failed to resize to \(size): \(error)\n".utf8))
        exit(1)
    }
}
