import XCTest
import SwiftUI
import UIKit
@testable import REACH

@MainActor
final class AdventureBookVisualFidelityTests: XCTestCase {
    func testTextureAtlasContainsAllSixUsableRegions() {
        XCTAssertEqual(AdventureArtwork.regions.count, 6)
        for image in AdventureArtwork.regions {
            XCTAssertGreaterThanOrEqual(image.size.width, 256)
            XCTAssertGreaterThanOrEqual(image.size.height, 512)
            XCTAssertNotNil(image.cgImage)
        }
    }

    func testReferenceFontsAreAvailableOnIOSWithoutRemoteDownloads() {
        for name in ["SnellRoundhand", "Noteworthy-Light", "Baskerville"] {
            XCTAssertNotNil(UIFont(name: name, size: 18), "Missing native reference font: \(name)")
        }
    }

    func testAllThreeNativeScreensCanRenderAtSmallAndLargePhoneSizes() {
        for width in [320.0, 430.0] {
            for page in 0...2 {
                let view = ReachAdventureBookPreview(initialPage: page)
                    .frame(width: width, height: 680)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                guard let image = renderer.uiImage else {
                    XCTFail("Could not render native sample screen \(page)"); continue
                }
                XCTAssertEqual(image.size.width, width, accuracy: 1)
                XCTAssertEqual(image.size.height, 680, accuracy: 1)
            }
        }
    }

    func testMemorySupportsAccessibilityTextAndReducedMotion() {
        let renderer = ImageRenderer(content: ReachAdventureBookPreview(initialPage: 2)
            .environment(\.dynamicTypeSize, .accessibility3)
            .environment(\.accessibilityReduceMotion, true)
            .frame(width: 320, height: 680))
        XCTAssertNotNil(renderer.uiImage)
    }
}
