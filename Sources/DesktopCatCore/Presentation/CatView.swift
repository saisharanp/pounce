import CoreGraphics
import Foundation
import SwiftUI

public enum CatHitArea {
    public static func contains(_ point: CGPoint, in bounds: CGRect) -> Bool {
        guard bounds.width > 0, bounds.height > 0 else { return false }
        let center = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.55)
        let radiusX = bounds.width * 0.44
        let radiusY = bounds.height * 0.44
        let normalizedX = (point.x - center.x) / radiusX
        let normalizedY = (point.y - center.y) / radiusY
        return normalizedX * normalizedX + normalizedY * normalizedY <= 1
    }
}

public enum CatGestureInterpreter {
    public static func interaction(
        translation: CGSize,
        duration: TimeInterval,
        recentContactCount: Int
    ) -> CatInteraction {
        let distance = hypot(translation.width, translation.height)
        let speed = Double(distance) / max(duration, 0.001)
        if recentContactCount >= 3 || speed >= 360 {
            return .hurriedAttention
        }
        return distance >= 4 ? .gentlePet : .click
    }
}

public struct CatAnimationTiming: Hashable, Sendable {
    public let closingMilliseconds: Int
    public let closedHoldMilliseconds: Int
    public let openingMilliseconds: Int

    public var totalMilliseconds: Int {
        closingMilliseconds + closedHoldMilliseconds + openingMilliseconds
    }

    public init(expression: CatExpression) {
        switch expression {
        case .blink:
            closingMilliseconds = 120
            closedHoldMilliseconds = 70
            openingMilliseconds = 160
        case .slowBlink:
            closingMilliseconds = 420
            closedHoldMilliseconds = 260
            openingMilliseconds = 480
        default:
            closingMilliseconds = 240
            closedHoldMilliseconds = 60
            openingMilliseconds = 320
        }
    }
}

public struct CatPose: Hashable, Sendable {
    public var bodyX = 0.0
    public var bodyY = 0.0
    public var bodyScaleX = 1.0
    public var bodyScaleY = 1.0
    public var bodyRotation = 0.0
    public var headX = 0.0
    public var headY = 0.0
    public var headRotation = 0.0
    public var tailRotation = 0.0
    public var frontPawY = 0.0
    public var pawAlternation = 0.0
    public var rearLegExtension = 0.0
    public var eyeScaleY = 1.0
    public var pupilX = 0.0
    public var pupilScale = 1.0
    public var earRotation = 0.0
    public var mouthOpen = 0.0
    public var muzzleScale = 1.0
    public var opacity = 1.0

    public init(
        activity: CatActivity,
        expression: CatExpression,
        phase: Bool,
        motionAllowed: Bool
    ) {
        apply(activity)
        apply(expression, phase: phase, motionAllowed: motionAllowed)
        if motionAllowed {
            applyMotion(activity, expression: expression, phase: phase)
        }
    }

    private mutating func apply(_ activity: CatActivity) {
        switch activity {
        case .sitting:
            tailRotation = 8
        case .loafing:
            bodyY = 5
            bodyScaleX = 1.08
            bodyScaleY = 0.88
            frontPawY = 5
        case .walking:
            bodyX = -2
            bodyY = 2
            bodyRotation = -2
            pawAlternation = 0.45
            tailRotation = -10
        case .sleeping:
            bodyY = 8
            bodyScaleX = 1.12
            bodyScaleY = 0.8
            headX = -8
            headY = 7
            headRotation = -10
            tailRotation = 18
            frontPawY = 5
            eyeScaleY = 0.08
        case .waking:
            bodyY = 4
            bodyScaleY = 0.96
            headY = 2
            headRotation = 5
            eyeScaleY = 0.72
        case .stretching:
            bodyX = 3
            bodyY = 7
            bodyScaleX = 1.15
            bodyScaleY = 0.82
            headX = 9
            headY = 6
            headRotation = -10
            rearLegExtension = 1
            tailRotation = -16
        case .grooming:
            bodyY = 3
            bodyRotation = -6
            headX = 4
            headY = 6
            headRotation = 42
            pawAlternation = 0.7
        case .kneading:
            bodyY = 4
            bodyScaleX = 1.02
            bodyScaleY = 0.95
            frontPawY = 4
            pawAlternation = 0.55
        case .lookingAround:
            headX = 4
            headRotation = 10
            pupilX = 0.22
            tailRotation = -8
        case .pouncing:
            bodyX = 5
            bodyY = 6
            bodyScaleX = 1.12
            bodyScaleY = 0.88
            bodyRotation = -7
            headX = 6
            headY = 2
            frontPawY = -2
            rearLegExtension = 0.8
            tailRotation = -20
        case .zooming:
            bodyX = 8
            bodyY = 3
            bodyScaleX = 1.15
            bodyScaleY = 0.86
            bodyRotation = -4
            headX = 7
            pawAlternation = 0.8
            rearLegExtension = 1
            tailRotation = -25
        case .hiding:
            bodyY = 12
            bodyScaleX = 0.88
            bodyScaleY = 0.9
            headY = 10
            opacity = 0.42
        case .peeking:
            bodyX = -5
            bodyY = 8
            headX = 8
            headY = -2
            headRotation = 7
            opacity = 0.76
        case .eating:
            bodyY = 7
            headY = 10
            headRotation = -14
            frontPawY = 2
            tailRotation = 12
        case .sunbathing:
            bodyX = -3
            bodyY = 5
            bodyScaleX = 1.1
            bodyScaleY = 0.9
            headRotation = -6
            tailRotation = 22
            eyeScaleY = 0.35
        }
    }

    private mutating func apply(
        _ expression: CatExpression,
        phase: Bool,
        motionAllowed: Bool
    ) {
        switch expression {
        case .neutral:
            break
        case .blink:
            eyeScaleY = motionAllowed && !phase ? 1 : 0.08
        case .slowBlink:
            eyeScaleY = motionAllowed && !phase ? 1 : 0.28
            headRotation -= 2
        case .purr:
            eyeScaleY = min(eyeScaleY, 0.55)
            muzzleScale = 1.06
            tailRotation += 4
        case .chirp:
            eyeScaleY = max(eyeScaleY, 1.05)
            headY -= 1
            mouthOpen = 0.4
        case .meow:
            headY -= 2
            mouthOpen = 0.85
        case .sideEye:
            eyeScaleY = min(eyeScaleY, 0.72)
            pupilX = 0.35
            earRotation = -10
        case .startled:
            eyeScaleY = 1.25
            pupilScale = 0.72
            earRotation = -16
            mouthOpen = 0.25
        }
    }

    private mutating func applyMotion(
        _ activity: CatActivity,
        expression: CatExpression,
        phase: Bool
    ) {
        let direction = phase ? 1.0 : -1.0

        switch activity {
        case .sitting:
            tailRotation += 5 * direction
            headY -= 0.6 * direction
        case .loafing:
            bodyScaleY += 0.012 * direction
            headY -= 0.5 * direction
        case .walking:
            bodyX += 4 * direction
            bodyY += direction
            pawAlternation += 0.3 * direction
            tailRotation -= 4 * direction
        case .sleeping:
            bodyScaleX += 0.012 * direction
            muzzleScale += 0.015 * direction
        case .waking:
            headY -= 1.5 * direction
            headRotation += 2 * direction
        case .stretching:
            bodyScaleX += 0.03 * direction
            rearLegExtension += 0.08 * direction
            tailRotation += 3 * direction
        case .grooming:
            headRotation += 3 * direction
            pawAlternation += 0.2 * direction
        case .kneading:
            frontPawY += 1.5 * direction
            pawAlternation += 0.4 * direction
            bodyScaleY += 0.012 * direction
        case .lookingAround:
            headRotation += 5 * direction
            pupilX += 0.12 * direction
            tailRotation += 4 * direction
        case .pouncing:
            bodyX += 3 * direction
            bodyY -= 4 * direction
            frontPawY -= 1.5 * direction
            tailRotation -= 4 * direction
        case .zooming:
            bodyX += 4 * direction
            bodyY -= 2 * direction
            pawAlternation += 0.5 * direction
            tailRotation -= 5 * direction
        case .hiding:
            opacity += 0.08 * direction
            headY -= direction
        case .peeking:
            headX += 3 * direction
            headRotation += 3 * direction
            opacity += 0.06 * direction
        case .eating:
            headY += 1.2 * direction
            headRotation += 2 * direction
        case .sunbathing:
            bodyScaleX += 0.012 * direction
            bodyScaleY += 0.008 * direction
            tailRotation += 2 * direction
        }

        switch expression {
        case .purr:
            bodyScaleX += 0.008 * direction
        case .chirp, .meow:
            mouthOpen += 0.08 * direction
        case .sideEye:
            pupilX += 0.06 * direction
            tailRotation += 5 * direction
        case .startled:
            bodyY -= 1.5 * direction
        case .neutral, .blink, .slowBlink:
            break
        }
    }
}

@MainActor
public struct CatView: View {
    @ObservedObject private var viewModel: CatViewModel
    @State private var phase = false
    @State private var dragStartedAt: Date?
    @State private var recentContacts: [Date] = []

    public init(viewModel: CatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        OrangeTabbyShape(
            pose: CatPose(
                activity: viewModel.activity,
                expression: viewModel.expression,
                phase: phase,
                motionAllowed: motionAllowed
            ),
            highContrast: viewModel.state.highContrast
        )
        .frame(width: 132, height: 132)
        .contentShape(CatHitAreaShape())
        .gesture(catGesture)
        .scaleEffect(catScale)
        .frame(width: 180, height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Orange tabby, \(viewModel.activity.rawValue)")
        .task(id: animationToken) {
            await playBoundedAnimation()
        }
    }

    private var motionAllowed: Bool {
        !viewModel.state.reducedMotion && !viewModel.state.isPaused
    }

    private var catScale: Double {
        min(max(viewModel.state.catScale, 0.65), 1.3)
    }

    private var animationToken: CatAnimationToken {
        CatAnimationToken(
            activity: viewModel.activity,
            expression: viewModel.expression,
            reactionNonce: viewModel.reactionNonce,
            motionAllowed: motionAllowed
        )
    }

    private var catGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { _ in
                if dragStartedAt == nil {
                    dragStartedAt = Date()
                }
            }
            .onEnded { value in
                let completedAt = Date()
                recentContacts = recentContacts.filter {
                    completedAt.timeIntervalSince($0) <= 0.8
                }
                recentContacts.append(completedAt)

                let interaction = CatGestureInterpreter.interaction(
                    translation: value.translation,
                    duration: completedAt.timeIntervalSince(dragStartedAt ?? completedAt),
                    recentContactCount: recentContacts.count
                )
                dragStartedAt = nil
                viewModel.handle(interaction)
            }
    }

    private func playBoundedAnimation() async {
        phase = false
        guard motionAllowed else { return }
        let timing = CatAnimationTiming(expression: viewModel.expression)

        withAnimation(.easeOut(duration: Double(timing.closingMilliseconds) / 1_000)) {
            phase = true
        }
        do {
            try await Task.sleep(
                for: .milliseconds(timing.closingMilliseconds + timing.closedHoldMilliseconds)
            )
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: Double(timing.openingMilliseconds) / 1_000)) {
            phase = false
        }
    }
}

private struct CatAnimationToken: Hashable {
    let activity: CatActivity
    let expression: CatExpression
    let reactionNonce: UInt64
    let motionAllowed: Bool
}

private struct CatHitAreaShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(
            ellipseIn: CGRect(
                x: rect.minX + rect.width * 0.06,
                y: rect.minY + rect.height * 0.11,
                width: rect.width * 0.88,
                height: rect.height * 0.88
            )
        )
    }
}
