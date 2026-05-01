//
//  Preferences.swift
//  caffeine
//
//  Created by BinaryLoader on 5/1/26.
//

import Foundation
import Observation
import SwiftUI

/// 사용자 설정 모델. 키-값 저장소에 영구 저장한다
///
/// 1.0.1에서 ObservableObject + @Published를 macOS 14의 `@Observable` 매크로로 마이그레이션했다.
/// `@Observable`은 KVO 기반 `objectWillChange`가 아니라 내부 트래커 기반이므로 SwiftUI는 매크로
/// 기반 변경 추적을 사용한다. SwiftUI 뷰는 `@EnvironmentObject` 대신 `@Environment(Preferences.self)`로
/// 받는다.
///
/// 과거에는 `@AppStorage`를 사용했지만 `@AppStorage`는 SwiftUI 뷰 트리 내부에서만 변경을 감지하고
/// 비-View 코드(예: `QuickTimerSection.applyPreset`)에서 값을 갱신해도 EnvironmentObject로 구독하는
/// 다른 뷰가 재렌더링되지 않아 칩 선택 상태/카운트다운 길이 등이 즉시 반영되지 않는 회귀가 있었다.
///
/// SleepFlag 5개 옵션은 named property 6중 반복(`var X: Bool { didSet { ... } }`)을 제거하고
/// `SleepFlag` 키 기반 subscript로 통합해 새 옵션 추가 시 dispatch가 한 곳에서 끝나도록 했다.
///
/// 저장소는 `KeyValueStore` 프로토콜로 추상화되어 있으며 기본값은 `UserDefaults.standard`다.
/// 단위 테스트에서는 in-memory store를 주입해 사용자 defaults를 오염시키지 않고 영속화 흐름을
/// 검증할 수 있다. UserDefaults 키 이름은 `SleepFlag.defaultsKey`를 통해 동일하게 유지해 기존
/// 사용자의 영속화된 값과 호환된다
///
/// `@MainActor` 격리는 1.0.1에서 추가했다. Preferences는 SwiftUI 뷰와 매니저에서 main actor
/// 컨텍스트에서만 read/write되므로 격리를 명시해 strict concurrency에서 binding 클로저의
/// `@Sendable` 캡처 경고를 제거한다. 매니저들과 동일한 격리 모델로 통일된다
@MainActor
@Observable
final class Preferences {

    /// SleepFlag와 무관한 고정 키
    private enum Key {

        static let lastTimerSeconds = "lastTimerSeconds"
        static let appLanguage = "appLanguage"
    }

    /// SleepFlag별 ON/OFF 상태
    ///
    /// `@Observable` 매크로가 dictionary 변경을 자동 추적한다. SwiftUI 뷰는 subscript
    /// (`preferences[.display]`)로 접근하며 dictionary 전체 변경이지만 SwiftUI는 keypath별
    /// diff로 실제 영향 받는 뷰만 갱신한다.
    ///
    /// `@ObservationIgnored`로 표시하지 않으면 매크로가 trackingProperty로 처리하므로 dictionary
    /// 변경 시 자동으로 뷰가 갱신된다
    private var flagsState: [SleepFlag: Bool] = [:]

    /// 마지막으로 사용한 타이머 길이(초). 0은 무제한을 의미한다
    var lastTimerSeconds: Int {
        didSet { store.set(lastTimerSeconds, forKey: Key.lastTimerSeconds) }
    }

    /// UI 언어 식별자(en/ko/ja). 시스템 로케일 매칭 후 fallback 값으로 초기화된다
    ///
    /// 외부에서는 `appLanguage` 컴퓨티드 프로퍼티를 통해서만 변경할 수 있다.
    /// raw 문자열을 직접 set 하지 못하도록 setter를 private로 닫아 잘못된 값(미지원 언어 코드)이
    /// 들어올 가능성을 차단한다
    private(set) var appLanguageRaw: String {
        didSet {
            store.set(appLanguageRaw, forKey: Key.appLanguage)
            cachedStrings = Localizations.strings(for: appLanguage)
        }
    }

    /// 현재 언어의 문자열 묶음을 캐시한 값
    ///
    /// `strings` computed property는 매 호출마다 enum switch와 LocalizedStrings 구조체 복사가
    /// 발생한다. SwiftUI 뷰가 매 재평가마다 호출하면 누적 비용이 무시할 수 없으므로
    /// `appLanguageRaw` 변경 시점에 한 번만 갱신해 캐시한 값을 노출한다
    private(set) var cachedStrings: LocalizedStrings

    /// 영속 저장소. UserDefaults 또는 테스트용 in-memory 구현
    @ObservationIgnored
    private let store: KeyValueStore

    init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store

        // 신규 설치 기본값을 보존하기 위해 register(defaults:)를 호출한다.
        // 이미 영속화된 값이 있으면 register는 무시되고 기존 값이 우선 사용된다
        var registry: [String: Any] = [
            Key.lastTimerSeconds: 0,
            Key.appLanguage: AppLanguage.defaultFromSystem().rawValue
        ]
        for flag in SleepFlag.allCases {
            registry[flag.defaultsKey] = flag.defaultValue
        }
        store.register(defaults: registry)

        // SleepFlag dictionary는 self 비-isolated 초기화 단계에서 한 번에 채운다.
        // 빈 dictionary로 시작하면 첫 read에서 nil이 반환되어 false fallback이 발동되는데
        // 사용자의 ON 상태(예: 디스플레이 방지)가 한 프레임 늦게 반영되는 회귀가 발생할 수 있다
        var initialFlags: [SleepFlag: Bool] = [:]
        for flag in SleepFlag.allCases {
            initialFlags[flag] = store.bool(forKey: flag.defaultsKey)
        }
        self.flagsState = initialFlags

        self.lastTimerSeconds = store.integer(forKey: Key.lastTimerSeconds)
        let initialRaw =
            store.string(forKey: Key.appLanguage)
            ?? AppLanguage.defaultFromSystem().rawValue
        self.appLanguageRaw = initialRaw
        let initialLanguage = AppLanguage(rawValue: initialRaw) ?? AppLanguage.defaultFromSystem()
        self.cachedStrings = Localizations.strings(for: initialLanguage)
    }

    /// SleepFlag 기반 subscript
    ///
    /// 신규 옵션 추가 시 enum case 한 곳만 늘리면 read/write/persist 경로가 모두 자동으로 따라온다.
    /// dictionary에 키가 없는 경우는 init에서 모든 case를 채워 두므로 정상 흐름에서는 발생하지 않으며
    /// 안전한 false 폴백을 둔다(SleepFlag enum이 새 case를 추가했지만 init이 아직 채우지 않은
    /// 경계 상황만 해당)
    subscript(flag: SleepFlag) -> Bool {
        get { flagsState[flag] ?? false }
        set {
            flagsState[flag] = newValue
            store.set(newValue, forKey: flag.defaultsKey)
        }
    }

    /// SwiftUI 뷰에 전달할 SleepFlag 바인딩을 생성한다
    ///
    /// `@Observable` 모델은 `@Bindable` 프로퍼티 래퍼를 사용해 binding을 만드는 것이 표준이지만
    /// dictionary subscript는 `@Bindable`로 직접 wrapping이 어려워 명시적 Binding 생성을 유지한다.
    /// `@Observable`이 set 경로에서 트래커를 자동 호출하므로 `@Published` 시절과 동일하게
    /// 영속화 + 뷰 갱신이 일관되게 동작한다.
    ///
    /// 클로저는 `@Sendable`이 아니므로 `Preferences` 자체에 `Sendable`을 강제하지 않아도 된다.
    /// SwiftUI Binding은 동일 isolation에서만 사용되므로 cross-actor 캡처가 발생하지 않는다
    func binding(for flag: SleepFlag) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?[flag] ?? false },
            set: { [weak self] newValue in self?[flag] = newValue }
        )
    }

    /// 무제한 모드 진입 시 호출. 타이머가 있을 때만 의미 있는 플래그(`-u`)를 모두 OFF로 되돌린다.
    /// 토글은 disable로 잠기지만 시각적으로 ON으로 남아 사용자에게 잘못된 인상을 주는 회귀를 방지한다
    func disableTimerOnlyFlags() {
        for flag in SleepFlag.allCases where flag.isTimerOnly {
            self[flag] = false
        }
    }

    /// appLanguageRaw를 enum 타입으로 노출한다. 잘못된 값이면 시스템 기본으로 폴백한다
    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? AppLanguage.defaultFromSystem() }
        set { appLanguageRaw = newValue.rawValue }
    }

    /// 현재 언어의 문자열 묶음(매 호출 시 새로 enum switch). 호환을 위해 유지하되 신규 코드는
    /// `cachedStrings`를 우선 사용한다
    var strings: LocalizedStrings {
        cachedStrings
    }

    /// 활성 옵션이 하나도 없으면 caffeinate가 즉시 종료되므로 false를 반환한다
    ///
    /// `-u`(user)는 단독으로는 caffeinate를 유지시키지 못하므로 hasAnySleepPrevention 판정에서
    /// 제외한다. 즉 시스템 잠자기를 실제로 막을 수 있는 옵션(`-d`/`-i`/`-m`/`-s`)이 하나라도
    /// 켜져 있어야 true를 반환한다
    var hasAnySleepPrevention: Bool {
        SleepFlag.allCases.contains(where: { flag in
            !flag.isTimerOnly && self[flag]
        })
    }
}
