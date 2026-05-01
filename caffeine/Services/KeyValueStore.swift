//
//  KeyValueStore.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation

/// 키-값 영속 저장소 추상화
///
/// `Preferences`가 `UserDefaults.standard`를 직접 사용하던 부분을 분리한다. 단위 테스트에서는
/// in-memory 구현으로 교체해 실제 사용자 defaults를 오염시키지 않고 영속화 흐름(읽기/쓰기/register)
/// 을 검증할 수 있다.
///
/// SwiftUI 뷰는 이 프로토콜을 직접 사용하지 않는다. `Preferences`만 의존하므로 `@EnvironmentObject`
/// 호환성에는 영향이 없다.
///
/// 격리 표시를 두지 않는 이유는 `UserDefaults`가 thread-safe하고 `Preferences` 자체도 메인 액터로
/// 격리하지 않기 때문이다(매니저들과 달리 Published 값만 들고 있어 SwiftUI 측의 격리만 따른다)
protocol KeyValueStore {

    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)

    func integer(forKey key: String) -> Int
    func set(_ value: Int, forKey key: String)

    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)

    /// 신규 설치 시 사용할 기본값을 등록한다. 이미 영속화된 값이 있으면 무시되고 기존 값이 우선된다
    func register(defaults: [String: Any])
}

/// `UserDefaults`를 `KeyValueStore`로 사용하기 위한 어댑터
///
/// `UserDefaults`는 이미 `bool/integer/string/set/register(defaults:)` 시그니처를 모두 갖고 있어
/// 별도 메서드 구현 없이 빈 conformance만 추가하면 된다. `set(_ value: String?, forKey:)`는
/// `UserDefaults`의 `set(_ value: Any?, forKey:)` 오버로드가 처리하므로 명시적 어댑터만 둔다
extension UserDefaults: KeyValueStore {

    /// `String?` 오버로드를 명시적으로 노출한다
    ///
    /// `UserDefaults`의 `set(_ value: Any?, forKey:)`는 nil 입력 시 키를 제거한다. 프로토콜은
    /// 명시적 `String?` 시그니처를 요구하므로 어댑터 메서드를 두어 호출을 위임한다
    func set(_ value: String?, forKey key: String) {
        set(value as Any?, forKey: key)
    }
}
