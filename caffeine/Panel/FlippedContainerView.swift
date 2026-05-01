//
//  FlippedContainerView.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit

/// 자식 뷰를 항상 상단(y = 0) 기준으로 anchor 하기 위한 flipped 컨테이너
///
/// AppKit 기본 좌표계(y-up)에서는 superview보다 큰 자식 뷰가 superview 하단에 정렬되어
/// 상단(헤더)이 위로 잘리는 문제가 있었다. `isFlipped`를 true로 두면 origin.y = 0이 상단을 의미해
/// 자식이 superview를 넘쳐도 헤더는 항상 보이고 하단만 잘린다. 좌표계 기능만 바꾸므로 시각 렌더
/// (글래스 패널 라운드, NSPanel 그림자/clear 배경)에는 영향이 없다
final class FlippedContainerView: NSView {

    override var isFlipped: Bool { true }
}
