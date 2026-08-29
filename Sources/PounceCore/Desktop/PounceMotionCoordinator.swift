import AppKit
import Foundation

public enum PounceMotionPath {
    public static func point(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        let t = min(max(progress, 0), 1)
        return CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }
}

/// Drives gentle autonomous movement while the panel is eligible to be shown.
/// All inputs are injectable so the scheduler is deterministic in checks.
@MainActor
public final class PounceMotionCoordinator {
    public typealias Eligibility = () -> Bool
    public typealias VisibleFrameProvider = () -> CGRect?
    public typealias DestinationProvider = (_ visibleFrame: CGRect, _ windowSize: CGSize) -> CGPoint

    private var task: Task<Void, Never>?
    private let eligibility: Eligibility
    private let visibleFrameProvider: VisibleFrameProvider
    private let destinationProvider: DestinationProvider
    private let interval: Duration
    private let travelDuration: TimeInterval

    public init(
        interval: Duration = .seconds(18),
        travelDuration: TimeInterval = 2.4,
        eligibility: @escaping Eligibility = { true },
        visibleFrameProvider: @escaping VisibleFrameProvider = {
            NSScreen.main?.visibleFrame
        },
        destinationProvider: @escaping DestinationProvider = { frame, windowSize in
            let maxX = max(frame.minX, frame.maxX - windowSize.width)
            let maxY = max(frame.minY, frame.maxY - windowSize.height)
            return CGPoint(
                x: CGFloat.random(in: frame.minX...maxX),
                y: CGFloat.random(in: frame.minY...maxY)
            )
        }
    ) {
        self.interval = interval
        self.travelDuration = max(0.1, travelDuration)
        self.eligibility = eligibility
        self.visibleFrameProvider = visibleFrameProvider
        self.destinationProvider = destinationProvider
    }

    public func start(windowController: PounceWindowController) {
        stop()
        let interval = self.interval
        let eligibility = self.eligibility
        let visibleFrameProvider = self.visibleFrameProvider
        let destinationProvider = self.destinationProvider
        let travelDuration = self.travelDuration
        task = Task { [weak windowController] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                guard !Task.isCancelled,
                      eligibility(),
                      let windowController,
                      let frame = visibleFrameProvider(),
                      let window = windowController.window else {
                    continue
                }
                let destination = destinationProvider(frame, window.frame.size)
                windowController.animateToPoint(
                    destination,
                    visibleFrame: frame,
                    duration: travelDuration
                )
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
