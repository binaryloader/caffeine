//
//  InMemoryKeyValueStore.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
@testable import caffeine

/// 사용자 defaults를 오염시키지 않고 영속화 흐름을 검증하기 위한 인메모리 저장소
///
/// 동작 방식은 `UserDefaults`와 동일하다
/// - `register(defaults:)`로 등록한 기본값은 set이 호출되기 전까지 read에 노출된다
/// - 한 번이라도 set이 호출되면 그 값이 우선되고 register 값은 가려진다
/// - 키 삭제는 `set(nil)`로 처리한다(`String?`만 지원하지만 Bool/Int는 set만 가능)
final class InMemoryKeyValueStore: KeyValueStore {

    private var explicit: [String: Any] = [:]
    private var registered: [String: Any] = [:]

    func bool(forKey key: String) -> Bool {
        if let value = explicit[key] as? Bool {
            return value
        }
        return registered[key] as? Bool ?? false
    }

    func set(_ value: Bool, forKey key: String) {
        explicit[key] = value
    }

    func integer(forKey key: String) -> Int {
        if let value = explicit[key] as? Int {
            return value
        }
        return registered[key] as? Int ?? 0
    }

    func set(_ value: Int, forKey key: String) {
        explicit[key] = value
    }

    func string(forKey key: String) -> String? {
        if let value = explicit[key] {
            return value as? String
        }
        return registered[key] as? String
    }

    func set(_ value: String?, forKey key: String) {
        if let value {
            explicit[key] = value
        } else {
            explicit.removeValue(forKey: key)
        }
    }

    func register(defaults: [String: Any]) {
        for (key, value) in defaults {
            // UserDefaults.register는 이미 등록된 같은 키가 있으면 새 값으로 덮는다(이번 호출 기준)
            registered[key] = value
        }
    }

    /// 테스트 편의용. 명시적 set 없이 등록만 된 상태인지 확인
    func hasExplicitValue(forKey key: String) -> Bool {
        explicit[key] != nil
    }
}
