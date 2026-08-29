import Foundation

public struct CatMood: Codable, Equatable {
    public var hunger: Double = 0.25
    public var affection: Double = 0.65
    public var energy: Double = 0.65
    public var playfulness: Double = 0.65

    public init(
        hunger: Double = 0.25,
        affection: Double = 0.65,
        energy: Double = 0.65,
        playfulness: Double = 0.65
    ) {
        self.hunger = hunger
        self.affection = affection
        self.energy = energy
        self.playfulness = playfulness
    }

    /// Applies a small, local passage-of-time update without degrading the
    /// companion's relationship or generating attention-seeking side effects.
    public func applyingElapsedCare(seconds: TimeInterval) -> CatMood {
        guard seconds.isFinite, seconds > 0 else { return self }

        var updated = self
        let elapsedDays = min(seconds / (24 * 60 * 60), 7)
        updated.hunger = min(max(updated.hunger, 0), 1) + elapsedDays * 0.06
        updated.hunger = min(updated.hunger, 1)
        updated.affection = min(max(updated.affection, 0), 1)
        updated.energy = min(max(updated.energy, 0), 1)
        updated.playfulness = min(max(updated.playfulness, 0), 1)
        return updated
    }
}
