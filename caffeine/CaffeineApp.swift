//
//  CaffeineApp.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// 메뉴바 단일 진입점은 AppDelegate가 책임진다
///
/// `Settings { EmptyView() }`는 SwiftUI App 라이프사이클을 만족시키기 위한 자리표시 씬이다
/// LSUIElement(YES)와 함께 동작하므로 메뉴 등의 UI는 표시되지 않는다
@main
struct CaffeineApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
