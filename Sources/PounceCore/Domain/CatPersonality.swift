public enum CatPersonality: String, CaseIterable, Codable {
    case playfulKitten, sleepyLoaf, curiousExplorer, dignifiedSenior

    public func weight(for activity: CatActivity) -> Int {
        switch (self, activity) {
        case (.playfulKitten, .pouncing), (.playfulKitten, .zooming): return 8
        case (.playfulKitten, .sleeping): return 2
        case (.sleepyLoaf, .sleeping), (.sleepyLoaf, .loafing): return 8
        case (.curiousExplorer, .walking), (.curiousExplorer, .lookingAround): return 8
        case (.dignifiedSenior, .sitting), (.dignifiedSenior, .sunbathing): return 7
        default: return 4
        }
    }
}
