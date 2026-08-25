public enum CatInteraction {
    case click
    case gentlePet
    case hurriedAttention
    case laser
    case yarn
    case feather
    case paperBall
    case treat
}

public enum CatExpression: String, Codable {
    case neutral
    case blink
    case slowBlink
    case purr
    case chirp
    case meow
    case sideEye
    case startled
}

public struct CatReaction: Equatable {
    public let activity: CatActivity
    public let expression: CatExpression

    public init(activity: CatActivity, expression: CatExpression) {
        self.activity = activity
        self.expression = expression
    }
}

public enum CatReactionResolver {
    public static func resolve(_ input: CatInteraction, mood: CatMood) -> CatReaction {
        _ = mood

        switch input {
        case .gentlePet:
            return CatReaction(activity: .kneading, expression: .slowBlink)
        case .hurriedAttention:
            return CatReaction(activity: .walking, expression: .sideEye)
        case .laser:
            return CatReaction(activity: .pouncing, expression: .neutral)
        case .yarn, .paperBall:
            return CatReaction(activity: .pouncing, expression: .chirp)
        case .feather:
            return CatReaction(activity: .lookingAround, expression: .chirp)
        case .treat:
            return CatReaction(activity: .eating, expression: .purr)
        case .click:
            return CatReaction(activity: .sitting, expression: .blink)
        }
    }
}
