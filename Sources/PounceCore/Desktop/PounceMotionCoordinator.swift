import AppKit
import Foundation

public enum CatRoamGait: Equatable, Sendable {
    case rest
    case stroll
    case pounce
    case zoom
}

public struct CatRoamPlan: Equatable, Sendable {
    public let gait: CatRoamGait
    public let destination: CGPoint
    public let duration: TimeInterval

    public var activity: CatActivity {
        switch gait {
        case .rest: .sitting
        case .stroll: .walking
        case .pounce: .pouncing
        case .zoom: .zooming
        }
    }

    public var hopHeight: CGFloat {
        CatRoam.hopHeight(for: gait)
    }
}

public enum CatRoam {
    public static func range(for gait: CatRoamGait) -> ClosedRange<CGFloat> {
        switch gait {
        case .rest: 0...0
        case .stroll: 90...240
        case .pounce: 48...130
        case .zoom: 280...720
        }
    }

    public static func hopHeight(for gait: CatRoamGait) -> CGFloat {
        switch gait {
        case .rest: 0
        case .stroll: 6
        case .pounce: 24
        case .zoom: 10
        }
    }

    public static func pickGait(unit: Double, personality: CatPersonality) -> CatRoamGait {
        let t = min(max(unit, 0), 1)
        switch personality {
        case .playfulKitten:
            switch t {
            case ..<0.12: return .rest
            case ..<0.52: return .stroll
            case ..<0.72: return .pounce
            default: return .zoom
            }
        case .sleepyLoaf:
            switch t {
            case ..<0.45: return .rest
            case ..<0.85: return .stroll
            case ..<0.95: return .pounce
            default: return .zoom
            }
        case .curiousExplorer:
            switch t {
            case ..<0.15: return .rest
            case ..<0.75: return .stroll
            case ..<0.87: return .pounce
            default: return .zoom
            }
        case .dignifiedSenior:
            switch t {
            case ..<0.35: return .rest
            case ..<0.85: return .stroll
            case ..<0.95: return .pounce
            default: return .zoom
            }
        }
    }

    public static func duration(distance: CGFloat, gait: CatRoamGait) -> TimeInterval {
        let speed: CGFloat
        let bounds: ClosedRange<TimeInterval>
        switch gait {
        case .rest:
            return 0
        case .stroll:
            speed = 160
            bounds = 0.55...2.2
        case .pounce:
            speed = 260
            bounds = 0.28...0.7
        case .zoom:
            speed = 520
            bounds = 0.45...1.5
        }
        let seconds = Double(distance / max(speed, 1))
        return min(max(seconds, bounds.lowerBound), bounds.upperBound)
    }

    public static func plan(
        from origin: CGPoint,
        windowSize: CGSize,
        visibleFrame: CGRect,
        gait: CatRoamGait,
        angle: CGFloat,
        distanceUnit: CGFloat
    ) -> CatRoamPlan? {
        guard gait != .rest else { return nil }

        let span = range(for: gait)
        let unit = min(max(distanceUnit, 0), 1)
        let requested = span.lowerBound + (span.upperBound - span.lowerBound) * unit
        let destination = clamp(
            CGPoint(
                x: origin.x + cos(angle) * requested,
                y: origin.y + sin(angle) * requested
            ),
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
        let distance = hypot(destination.x - origin.x, destination.y - origin.y)
        guard distance >= 24 else { return nil }

        return CatRoamPlan(
            gait: gait,
            destination: destination,
            duration: duration(distance: distance, gait: gait)
        )
    }

    private static func clamp(
        _ origin: CGPoint,
        windowSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)
        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maximumX),
            y: min(max(origin.y, visibleFrame.minY), maximumY)
        )
    }
}

public enum PounceMotionPath {
    public static func point(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        let t = min(max(progress, 0), 1)
        return CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }

    public static func easedProgress(_ progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        return t * t * (3 - 2 * t)
    }

    public static func hopOffset(progress: Double, height: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1)
        guard t > 0, t < 1 else { return 0 }
        return sin(t * .pi) * height
    }
}

/// Drives gentle autonomous movement while the panel is eligible to be shown.
/// All inputs are injectable so the scheduler is deterministic in checks.
@MainActor
public final class PounceMotionCoordinator {
    public typealias Eligibility = () -> Bool
    public typealias VisibleFrameProvider = () -> CGRect?
    public typealias IntervalProvider = () -> ClosedRange<Int>
    public typealias PlanProvider = (_ origin: CGPoint, _ visibleFrame: CGRect, _ windowSize: CGSize) -> CatRoamPlan?

    private var task: Task<Void, Never>?
    private let eligibility: Eligibility
    private let visibleFrameProvider: VisibleFrameProvider
    private let planProvider: PlanProvider
    private let interval: IntervalProvider

    public init(
        interval: @escaping IntervalProvider = { 4...8 },
        eligibility: @escaping Eligibility = { true },
        visibleFrameProvider: @escaping VisibleFrameProvider = {
            NSScreen.main?.visibleFrame
        },
        planProvider: @escaping PlanProvider = { origin, frame, windowSize in
            CatRoam.plan(
                from: origin,
                windowSize: windowSize,
                visibleFrame: frame,
                gait: CatRoam.pickGait(unit: .random(in: 0..<1), personality: .playfulKitten),
                angle: .random(in: 0..<(2 * .pi)),
                distanceUnit: .random(in: 0...1)
            )
        }
    ) {
        self.interval = interval
        self.eligibility = eligibility
        self.visibleFrameProvider = visibleFrameProvider
        self.planProvider = planProvider
    }

    public func start(windowController: PounceWindowController) {
        stop()
        let interval = self.interval
        let eligibility = self.eligibility
        let visibleFrameProvider = self.visibleFrameProvider
        let planProvider = self.planProvider
        task = Task { [weak windowController] in
            while !Task.isCancelled {
                let seconds = max(1, Int.random(in: interval()))
                do {
                    try await Task.sleep(for: .seconds(seconds))
                } catch {
                    return
                }
                guard !Task.isCancelled,
                      eligibility(),
                      let windowController,
                      let frame = visibleFrameProvider(),
                      let window = windowController.window,
                      let plan = planProvider(window.frame.origin, frame, window.frame.size) else {
                    continue
                }
                await windowController.animateToPoint(
                    plan.destination,
                    visibleFrame: frame,
                    duration: plan.duration,
                    activity: plan.activity,
                    hopHeight: plan.hopHeight
                )
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
