import XCTest
@testable import DesktopCat

final class CatActivityTests: XCTestCase {
    func testPlayfulPersonalityPrefersPlayOverSleep() {
        XCTAssertGreaterThan(
            CatPersonality.playfulKitten.weight(for: .pouncing),
            CatPersonality.playfulKitten.weight(for: .sleeping)
        )
    }
}
