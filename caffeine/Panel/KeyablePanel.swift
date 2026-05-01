//
//  KeyablePanel.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import AppKit

/// `canBecomeKey`를 강제로 true로 오버라이드한 NSPanel 서브클래스
///
/// `.nonactivatingPanel` 스타일 마스크의 NSPanel은 기본적으로 `canBecomeKey`가 false라서
/// SwiftUI `TextField`가 first responder를 받지 못해 키 입력이 라우팅되지 않는다. 메뉴바 앱
/// 표준 동작(NSApp 자체는 활성화하지 않음)은 유지하면서 패널만 key window로 만들 수 있도록
/// `canBecomeKey`만 true로 강제한다. `canBecomeMain`은 false 기본값을 유지해 메인 윈도우는 되지 않는다
final class KeyablePanel: NSPanel {

    override var canBecomeKey: Bool { true }
}
