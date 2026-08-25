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
}
