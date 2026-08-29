import Foundation

/// Chooses the next idle activity from personality, time of day, and mood.
///
/// The random index is injected so callers can provide a seeded source (and
/// checks can exercise selection without relying on global randomness).
public struct CatScheduler {
    public let randomIndex: (Int) -> Int

    public init(randomIndex: @escaping (Int) -> Int) {
        self.randomIndex = randomIndex
    }

    /// Activities in the last two positions are on cooldown. The timestamp is
    /// accepted as part of the scheduler interface so future cooldown policies
    /// can use it without changing callers; history is the current cooldown
    /// source because it carries no hidden clock state.
    public func isAllowed(
        _ activity: CatActivity,
        now: Date,
        recentActivities: [CatActivity]
    ) -> Bool {
        _ = now
        return !recentActivities.suffix(2).contains(activity)
    }

    public func nextIdleActivity(
        now: Date,
        personality: CatPersonality,
        mood: CatMood,
        recentActivities: [CatActivity]
    ) -> CatActivity {
        let allowed = CatActivity.allCases.filter {
            isAllowed($0, now: now, recentActivities: recentActivities)
        }

        let pool = allowed.flatMap { activity in
            let weight = personality.weight(for: activity)
            let multiplier = timeOfDayMultiplier(for: activity, now: now)
                * moodMultiplier(for: activity, mood: mood)
            let count = max(1, Int((Double(weight) * multiplier).rounded()))
            return Array(repeating: activity, count: count)
        }

        guard !pool.isEmpty else { return .sitting }

        // Modulo also handles an injected index larger than the pool. Taking
        // the remainder before correcting its sign avoids abs(Int.min)
        // overflow while keeping every result in the valid array range.
        let remainder = randomIndex(pool.count) % pool.count
        let index = remainder >= 0 ? remainder : remainder + pool.count
        return pool[index]
    }

    private func timeOfDayMultiplier(for activity: CatActivity, now: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: now)

        switch hour {
        case 0..<6:
            switch activity {
            case .sleeping: return 4.0
            case .loafing, .sitting: return 2.0
            case .waking, .stretching: return 1.25
            default: return 0.6
            }
        case 6..<11:
            switch activity {
            case .waking, .stretching, .grooming, .eating: return 2.0
            case .sleeping: return 0.5
            default: return 1.0
            }
        case 11..<17:
            switch activity {
            case .sunbathing, .sitting, .loafing: return 1.75
            case .sleeping: return 1.25
            case .pouncing, .zooming: return 1.1
            default: return 1.0
            }
        case 17..<22:
            switch activity {
            case .pouncing, .zooming, .walking, .lookingAround: return 1.5
            case .eating, .grooming: return 1.25
            case .sleeping: return 0.75
            default: return 1.0
            }
        default:
            switch activity {
            case .sleeping, .loafing, .sitting: return 2.5
            case .pouncing, .zooming: return 0.75
            default: return 1.0
            }
        }
    }

    private func moodMultiplier(for activity: CatActivity, mood: CatMood) -> Double {
        let energy = mood.energy.clamped(to: 0...1)
        let hunger = mood.hunger.clamped(to: 0...1)
        let affection = mood.affection.clamped(to: 0...1)
        let playfulness = mood.playfulness.clamped(to: 0...1)

        switch activity {
        case .pouncing, .zooming:
            return 0.35 + energy + playfulness
        case .walking, .lookingAround, .peeking:
            return 0.5 + energy
        case .eating:
            return 0.5 + (hunger * 2.0)
        case .grooming, .kneading:
            return 0.75 + affection
        case .sleeping, .loafing, .sitting, .sunbathing:
            return 0.75 + (1.0 - energy)
        case .waking, .stretching, .hiding:
            return 0.75 + (energy * 0.5)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
