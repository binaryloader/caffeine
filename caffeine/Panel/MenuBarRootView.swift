//
//  MenuBarRootView.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import SwiftUI

/// `NSHostingView`의 RootView generic을 안정적인 구체 타입으로 만들기 위한 래퍼
///
/// `MenuBarContentView`를 `AnyView`로 감싸면 SwiftUI 식별성이 깨져 ViewUpdater가
/// 매 프레임 트리를 재구성하면서 무한 재귀로 스택 오버플로우를 일으킨 사례가 있어 그를 회피한다
///
/// 1.0.1의 `@Observable` 마이그레이션 이후 매니저는 `.environment(_:)` 모디파이어를 통해
/// 자식 뷰 트리에 주입한다. ObservableObject 시절의 `.environmentObject(_:)` 대신
/// `@Observable`이 요구하는 `.environment(_:)` API를 사용한다
struct MenuBarRootView: View {

    let manager: CaffeinateManager
    let preferences: Preferences
    let loginItem: LoginItemManager

    var body: some View {
        MenuBarContentView()
            .environment(manager)
            .environment(preferences)
            .environment(loginItem)
            .fixedSize(horizontal: false, vertical: true)
    }
}
