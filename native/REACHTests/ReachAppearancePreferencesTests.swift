import XCTest
@testable import REACH

final class ReachAppearancePreferencesTests: XCTestCase {
    func testCommercialDefaultsContainNoPersonalNamesOrReligiousMessage() {
        let preferences = ReachAppearancePreferences()
        XCTAssertEqual(preferences.ownLabel, "You")
        XCTAssertEqual(preferences.partnerLabel, "Your partner")
        XCTAssertEqual(preferences.personalMessage, "")
        XCTAssertFalse(preferences.showMessage)
    }
    func testLocalCustomizationRoundTripsAndBoundsDisplayLabels() throws {
        var preferences = ReachAppearancePreferences()
        preferences.ownName = String(repeating: "A", count: 80)
        preferences.partnerName = "  "
        preferences.personalMessage = "Our own words"
        preferences.showMessage = true
        XCTAssertEqual(preferences.ownLabel.count, 40)
        XCTAssertEqual(preferences.partnerLabel, "Your partner")
        let copy = try JSONDecoder().decode(ReachAppearancePreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(copy, preferences)
    }
}
