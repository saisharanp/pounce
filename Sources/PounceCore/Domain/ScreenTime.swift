import Foundation
import UserNotifications

public struct ScreenTimeSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var endedAt: Date?

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public func duration(at now: Date) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }
}

public struct ScreenTimeSummary: Equatable, Sendable {
    public let sessionCount: Int
    public let totalSeconds: TimeInterval

    public init(sessionCount: Int, totalSeconds: TimeInterval) {
        self.sessionCount = sessionCount
        self.totalSeconds = totalSeconds
    }
}

public enum ScreenTimeCalculator {
    public static func summary(
        sessions: [ScreenTimeSession],
        from start: Date,
        until now: Date
    ) -> ScreenTimeSummary {
        let relevant = sessions.filter { $0.startedAt < now && ($0.endedAt ?? now) >= start }
        let seconds = relevant.reduce(0) { total, session in
            let clippedStart = max(session.startedAt, start)
            let clippedEnd = min(session.endedAt ?? now, now)
            return total + max(0, clippedEnd.timeIntervalSince(clippedStart))
        }
        return ScreenTimeSummary(sessionCount: relevant.count, totalSeconds: seconds)
    }

    public static func shouldPromptBreak(
        sessionStartedAt: Date?,
        now: Date,
        intervalMinutes: Int,
        isPaused: Bool
    ) -> Bool {
        guard let sessionStartedAt, !isPaused, intervalMinutes > 0 else { return false }
        return now.timeIntervalSince(sessionStartedAt) >= TimeInterval(intervalMinutes * 60)
    }
}

public protocol ScreenTimeReminderScheduling {
    func requestAuthorization()
    func scheduleBreakReminder(after seconds: TimeInterval)
    func cancelBreakReminder()
}

public struct SystemScreenTimeReminderScheduler: ScreenTimeReminderScheduling {
    public init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func scheduleBreakReminder(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Pounce break reminder"
        content.body = "You’ve been focused for a while. Stretch, hydrate, and give your eyes a rest."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "pounce-break-reminder", content: content, trigger: trigger)) { _ in }
    }

    public func cancelBreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pounce-break-reminder"])
    }
}

public struct NoopScreenTimeReminderScheduler: ScreenTimeReminderScheduling {
    public init() {}
    public func requestAuthorization() {}
    public func scheduleBreakReminder(after seconds: TimeInterval) {}
    public func cancelBreakReminder() {}
}
