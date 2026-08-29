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

public enum AttentionLevel: String, CaseIterable, Codable, Equatable {
    case calm
    case balanced
    case lively
}

/// The local, lightweight state restored when the companion launches.
public struct PetState: Codable, Equatable {
    public var personality: CatPersonality
    public var mood: CatMood
    public var lastCareUpdate: Date?
    public var isMuted: Bool
    public var isPaused: Bool
    public var clickThrough: Bool
    public var reducedMotion: Bool
    public var highContrast: Bool
    public var catScale: Double
    public var windowOrigin: ScreenRelativePoint
    public var windowDisplayIdentifier: String?
    public var windowLevel: PetWindowLevel
    public var soundVolume: Double
    public var hideInFullscreen: Bool
    public var attentionLevel: AttentionLevel
    public var roamingEnabled: Bool
    public var screenTimeEnabled: Bool
    public var focusSessionMinutes: Int
    public var breakIntervalMinutes: Int
    public var screenTimeSessions: [ScreenTimeSession]

    public init(
        personality: CatPersonality = .playfulKitten,
        mood: CatMood = .init(),
        lastCareUpdate: Date? = nil,
        isMuted: Bool = false,
        isPaused: Bool = false,
        clickThrough: Bool = false,
        reducedMotion: Bool = false,
        highContrast: Bool = false,
        catScale: Double = 1.0,
        windowOrigin: ScreenRelativePoint = .init(),
        windowDisplayIdentifier: String? = nil,
        windowLevel: PetWindowLevel = .desktop,
        soundVolume: Double = 0.65,
        hideInFullscreen: Bool = true,
        attentionLevel: AttentionLevel = .balanced,
        roamingEnabled: Bool = true,
        screenTimeEnabled: Bool = false,
        focusSessionMinutes: Int = 25,
        breakIntervalMinutes: Int = 45,
        screenTimeSessions: [ScreenTimeSession] = []
    ) {
        self.personality = personality
        self.mood = mood
        self.lastCareUpdate = lastCareUpdate
        self.isMuted = isMuted
        self.isPaused = isPaused
        self.clickThrough = clickThrough
        self.reducedMotion = reducedMotion
        self.highContrast = highContrast
        self.catScale = catScale
        self.windowOrigin = windowOrigin
        self.windowDisplayIdentifier = windowDisplayIdentifier
        self.windowLevel = windowLevel
        self.soundVolume = Self.clampedVolume(soundVolume)
        self.hideInFullscreen = hideInFullscreen
        self.attentionLevel = attentionLevel
        self.roamingEnabled = roamingEnabled
        self.screenTimeEnabled = screenTimeEnabled
        self.focusSessionMinutes = Self.clampedMinutes(focusSessionMinutes, defaultValue: 25)
        self.breakIntervalMinutes = Self.clampedMinutes(breakIntervalMinutes, defaultValue: 45)
        self.screenTimeSessions = screenTimeSessions
    }

    private enum CodingKeys: String, CodingKey {
        case personality
        case mood
        case lastCareUpdate
        case isMuted
        case isPaused
        case clickThrough
        case reducedMotion
        case highContrast
        case catScale
        case windowOrigin
        case windowDisplayIdentifier
        case windowLevel
        case soundVolume
        case hideInFullscreen
        case attentionLevel
        case roamingEnabled
        case screenTimeEnabled
        case focusSessionMinutes
        case breakIntervalMinutes
        case screenTimeSessions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        personality = try container.decodeIfPresent(CatPersonality.self, forKey: .personality) ?? .playfulKitten
        mood = try container.decodeIfPresent(CatMood.self, forKey: .mood) ?? .init()
        lastCareUpdate = try? container.decode(Date.self, forKey: .lastCareUpdate)
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        clickThrough = try container.decodeIfPresent(Bool.self, forKey: .clickThrough) ?? false
        reducedMotion = try container.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? false
        highContrast = try container.decodeIfPresent(Bool.self, forKey: .highContrast) ?? false
        catScale = try container.decodeIfPresent(Double.self, forKey: .catScale) ?? 1.0
        windowOrigin = try container.decodeIfPresent(ScreenRelativePoint.self, forKey: .windowOrigin) ?? .init()
        windowDisplayIdentifier = try container.decodeIfPresent(String.self, forKey: .windowDisplayIdentifier)
        windowLevel = try container.decodeIfPresent(PetWindowLevel.self, forKey: .windowLevel) ?? .desktop
        soundVolume = Self.clampedVolume(
            (try? container.decodeIfPresent(Double.self, forKey: .soundVolume)) ?? 0.65
        )
        hideInFullscreen =
            (try? container.decodeIfPresent(Bool.self, forKey: .hideInFullscreen)) ?? true
        attentionLevel =
            (try? container.decodeIfPresent(AttentionLevel.self, forKey: .attentionLevel)) ?? .balanced
        roamingEnabled = try container.decodeIfPresent(Bool.self, forKey: .roamingEnabled) ?? true
        screenTimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .screenTimeEnabled) ?? false
        focusSessionMinutes = Self.clampedMinutes(
            (try? container.decodeIfPresent(Int.self, forKey: .focusSessionMinutes)) ?? 25,
            defaultValue: 25
        )
        breakIntervalMinutes = Self.clampedMinutes(
            (try? container.decodeIfPresent(Int.self, forKey: .breakIntervalMinutes)) ?? 45,
            defaultValue: 45
        )
        screenTimeSessions = (try? container.decodeIfPresent([ScreenTimeSession].self, forKey: .screenTimeSessions)) ?? []
    }

    public static func clampedVolume(_ volume: Double) -> Double {
        guard volume.isFinite else { return 0.65 }
        return min(max(volume, 0), 1)
    }

    public static func clampedMinutes(_ minutes: Int, defaultValue: Int) -> Int {
        guard minutes > 0 else { return defaultValue }
        return min(max(minutes, 1), 240)
    }
}
