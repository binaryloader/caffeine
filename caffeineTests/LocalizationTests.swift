//
//  LocalizationTests.swift
//  caffeineTests
//
//  Created by BinaryLoader on 5/1/26.
//

import XCTest
@testable import caffeine

/// 다국어 사전(Localizations)의 완결성 검증
///
/// 새 SleepFlag을 추가하거나 새 사용자 노출 문자열을 추가했을 때 한 언어만 채우고 다른 언어를
/// 누락하면 런타임에서야 빈 문자열이 노출된다. 사전 단위 테스트로 컴파일 타임 가까이로
/// 누락 감지를 끌어올린다
final class LocalizationTests: XCTestCase {

    // MARK: - AppLanguage

    func test_AppLanguage_allCases는_ko_en_ja_3개() {
        XCTAssertEqual(AppLanguage.allCases.count, 3)
        XCTAssertTrue(AppLanguage.allCases.contains(.ko))
        XCTAssertTrue(AppLanguage.allCases.contains(.en))
        XCTAssertTrue(AppLanguage.allCases.contains(.ja))
    }

    func test_AppLanguage_shortLabel은_KO_EN_JA() {
        XCTAssertEqual(AppLanguage.ko.shortLabel, "KO")
        XCTAssertEqual(AppLanguage.en.shortLabel, "EN")
        XCTAssertEqual(AppLanguage.ja.shortLabel, "JA")
    }

    // MARK: - 모든 언어 사전이 채워져 있다

    func test_strings는_모든_AppLanguage에_대해_빈_문자열이_없다() {
        for language in AppLanguage.allCases {
            let strings = Localizations.strings(for: language)
            XCTAssertFalse(strings.active.isEmpty, "\(language) active 비어있음")
            XCTAssertFalse(strings.inactive.isEmpty, "\(language) inactive 비어있음")
            XCTAssertFalse(strings.left.isEmpty, "\(language) left 비어있음")
            XCTAssertFalse(strings.quickTimer.isEmpty, "\(language) quickTimer 비어있음")
            XCTAssertFalse(strings.options.isEmpty, "\(language) options 비어있음")
            XCTAssertFalse(strings.custom.isEmpty, "\(language) custom 비어있음")
            XCTAssertFalse(strings.customTimer.isEmpty, "\(language) customTimer 비어있음")
            XCTAssertFalse(strings.cancel.isEmpty, "\(language) cancel 비어있음")
            XCTAssertFalse(strings.start.isEmpty, "\(language) start 비어있음")
            XCTAssertFalse(strings.hours.isEmpty, "\(language) hours 비어있음")
            XCTAssertFalse(strings.minutes.isEmpty, "\(language) minutes 비어있음")
            XCTAssertFalse(strings.language.isEmpty, "\(language) language 비어있음")
            XCTAssertFalse(strings.quit.isEmpty, "\(language) quit 비어있음")
            XCTAssertFalse(strings.appSettings.isEmpty, "\(language) appSettings 비어있음")
            XCTAssertFalse(strings.launchAtLogin.isEmpty, "\(language) launchAtLogin 비어있음")
            XCTAssertFalse(
                strings.launchAtLoginDescription.isEmpty,
                "\(language) launchAtLoginDescription 비어있음"
            )
            XCTAssertFalse(
                strings.launchAtLoginErrorHint.isEmpty,
                "\(language) launchAtLoginErrorHint 비어있음"
            )
            XCTAssertFalse(strings.githubProfile.isEmpty, "\(language) githubProfile 비어있음")
        }
    }

    func test_접근성_라벨이_모든_언어에_채워져_있다() {
        for language in AppLanguage.allCases {
            let strings = Localizations.strings(for: language)
            XCTAssertFalse(
                strings.mainToggleAccessibilityLabel.isEmpty,
                "\(language) mainToggleAccessibilityLabel 비어있음"
            )
            XCTAssertFalse(
                strings.optionsExpandedAccessibility.isEmpty,
                "\(language) optionsExpandedAccessibility 비어있음"
            )
            XCTAssertFalse(
                strings.optionsCollapsedAccessibility.isEmpty,
                "\(language) optionsCollapsedAccessibility 비어있음"
            )
            XCTAssertFalse(
                strings.timerPresetAccessibilityHint.isEmpty,
                "\(language) timerPresetAccessibilityHint 비어있음"
            )
            XCTAssertFalse(
                strings.toggleOnAccessibility.isEmpty,
                "\(language) toggleOnAccessibility 비어있음"
            )
            XCTAssertFalse(
                strings.toggleOffAccessibility.isEmpty,
                "\(language) toggleOffAccessibility 비어있음"
            )
            XCTAssertFalse(
                strings.launchAtLoginAccessibilityLabel.isEmpty,
                "\(language) launchAtLoginAccessibilityLabel 비어있음"
            )
            XCTAssertFalse(
                strings.languageAccessibilityLabel.isEmpty,
                "\(language) languageAccessibilityLabel 비어있음"
            )
        }
    }

    func test_timerLabels가_모든_언어에_채워져_있다() {
        for language in AppLanguage.allCases {
            let labels = Localizations.strings(for: language).timerLabels
            XCTAssertFalse(labels.infinity.isEmpty, "\(language) infinity 비어있음")
            XCTAssertFalse(labels.fiveMinutes.isEmpty, "\(language) 5m 비어있음")
            XCTAssertFalse(labels.fifteenMinutes.isEmpty, "\(language) 15m 비어있음")
            XCTAssertFalse(labels.thirtyMinutes.isEmpty, "\(language) 30m 비어있음")
            XCTAssertFalse(labels.oneHour.isEmpty, "\(language) 1h 비어있음")
            XCTAssertFalse(labels.twoHours.isEmpty, "\(language) 2h 비어있음")
            XCTAssertFalse(labels.fiveHours.isEmpty, "\(language) 5h 비어있음")
        }
    }

    // MARK: - flags 매핑

    func test_모든_언어가_SleepFlag_5종에_대한_FlagText를_제공한다() {
        for language in AppLanguage.allCases {
            let strings = Localizations.strings(for: language)
            XCTAssertEqual(
                strings.flags.count,
                SleepFlag.allCases.count,
                "\(language)의 flags 개수가 SleepFlag.allCases와 다르다"
            )
            for flag in SleepFlag.allCases {
                let entry = strings.flags.first(where: { $0.flag == flag })
                XCTAssertNotNil(entry, "\(language)의 flags에 \(flag)가 없음")
                XCTAssertFalse(entry?.label.isEmpty ?? true, "\(language) \(flag).label 비어있음")
                XCTAssertFalse(
                    entry?.description.isEmpty ?? true,
                    "\(language) \(flag).description 비어있음"
                )
            }
        }
    }

    // MARK: - 시스템 로케일 폴백

    func test_AppLanguage_defaultFromSystem은_지원_언어_중_하나를_반환한다() {
        let result = AppLanguage.defaultFromSystem()
        XCTAssertTrue(AppLanguage.allCases.contains(result))
    }
}
