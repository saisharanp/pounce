import Foundation

/// A normalized position on the current screen, expressed as fractions of its
/// visible frame. The window controller is responsible for converting this to
/// a screen origin and clamping it when the display changes.
public struct ScreenRelativePoint: Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0.5, y: Double = 0.5) {
        self.x = x
        self.y = y
    }
}

/// The supported window placement levels without coupling the domain state to
/// AppKit's NSWindow.Level type.
public enum PetWindowLevel: String, Codable, Equatable {
    case desktop
    case floating
}

/// The local, lightweight state restored when the companion launches.
public struct PetState: Codable, Equatable {
    public var personality: CatPersonality
    public var mood: CatMood
    public var isMuted: Bool
    public var isPaused: Bool
    public var clickThrough: Bool
    public var reducedMotion: Bool
    public var highContrast: Bool
    public var catScale: Double
    public var windowOrigin: ScreenRelativePoint
    public var windowLevel: PetWindowLevel

    public init(
        personality: CatPersonality = .playfulKitten,
        mood: CatMood = .init(),
        isMuted: Bool = false,
        isPaused: Bool = false,
        clickThrough: Bool = false,
        reducedMotion: Bool = false,
        highContrast: Bool = false,
        catScale: Double = 1.0,
        windowOrigin: ScreenRelativePoint = .init(),
        windowLevel: PetWindowLevel = .desktop
    ) {
        self.personality = personality
        self.mood = mood
        self.isMuted = isMuted
        self.isPaused = isPaused
        self.clickThrough = clickThrough
        self.reducedMotion = reducedMotion
        self.highContrast = highContrast
        self.catScale = catScale
        self.windowOrigin = windowOrigin
        self.windowLevel = windowLevel
    }

    private enum CodingKeys: String, CodingKey {
        case personality
        case mood
        case isMuted
        case isPaused
        case clickThrough
        case reducedMotion
        case highContrast
        case catScale
        case windowOrigin
        case windowLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        personality = try container.decodeIfPresent(CatPersonality.self, forKey: .personality) ?? .playfulKitten
        mood = try container.decodeIfPresent(CatMood.self, forKey: .mood) ?? .init()
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        clickThrough = try container.decodeIfPresent(Bool.self, forKey: .clickThrough) ?? false
        reducedMotion = try container.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? false
        highContrast = try container.decodeIfPresent(Bool.self, forKey: .highContrast) ?? false
        catScale = try container.decodeIfPresent(Double.self, forKey: .catScale) ?? 1.0
        windowOrigin = try container.decodeIfPresent(ScreenRelativePoint.self, forKey: .windowOrigin) ?? .init()
        windowLevel = try container.decodeIfPresent(PetWindowLevel.self, forKey: .windowLevel) ?? .desktop
    }
}
