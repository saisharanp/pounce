import Testing
@testable import DesktopCat

@Test
func playfulPersonalityPrefersPlayOverSleep() {
    #expect(
        CatPersonality.playfulKitten.weight(for: .pouncing)
            > CatPersonality.playfulKitten.weight(for: .sleeping)
    )
}
