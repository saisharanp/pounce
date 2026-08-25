import Darwin
import CoreGraphics
import DesktopCatCore
import Foundation

private struct CheckCase {
    let name: String
    let run: () throws -> Void
}

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private let checks = [
    CheckCase(name: "playfulPersonalityPrefersPlayOverSleep") {
        let playWeight = CatPersonality.playfulKitten.weight(for: .pouncing)
        let sleepWeight = CatPersonality.playfulKitten.weight(for: .sleeping)

        guard playWeight > sleepWeight else {
            throw CheckFailure(
                description: "expected pouncing weight (\(playWeight)) to exceed sleeping weight (\(sleepWeight))"
            )
        }
    },
    CheckCase(name: "schedulerDoesNotRepeatRecentActivity") {
        let scheduler = CatScheduler(randomIndex: { _ in 0 })
        let next = scheduler.nextIdleActivity(
            now: Date(timeIntervalSince1970: 12 * 60 * 60),
            personality: .playfulKitten,
            mood: CatMood(),
            recentActivities: [.pouncing]
        )

        guard next != .pouncing else {
            throw CheckFailure(description: "scheduler repeated recent activity: pouncing")
        }
    },
    CheckCase(name: "lateNightBiasAllowsSleeping") {
        let scheduler = CatScheduler(randomIndex: { _ in 0 })
        let isAllowed = scheduler.isAllowed(
            .sleeping,
            now: Date(timeIntervalSince1970: 2 * 60 * 60),
            recentActivities: []
        )

        guard isAllowed else {
            throw CheckFailure(description: "sleeping should be allowed late at night")
        }
    },
    CheckCase(name: "gentlePettingReturnsAffectionateReaction") {
        let reaction = CatReactionResolver.resolve(.gentlePet, mood: CatMood())

        guard reaction.activity == .kneading else {
            throw CheckFailure(description: "gentle petting should trigger kneading")
        }
        guard reaction.expression == .slowBlink else {
            throw CheckFailure(description: "gentle petting should trigger a slow blink")
        }
    },
    CheckCase(name: "fastRepeatedInputReturnsMildAnnoyance") {
        let reaction = CatReactionResolver.resolve(.hurriedAttention, mood: CatMood())

        guard reaction.expression == .sideEye else {
            throw CheckFailure(description: "hurried attention should trigger a side-eye")
        }
    },
    CheckCase(name: "laserProducesPouncingReaction") {
        let reaction = CatReactionResolver.resolve(.laser, mood: CatMood())

        guard reaction == CatReaction(activity: .pouncing, expression: .neutral) else {
            throw CheckFailure(description: "laser should trigger neutral pouncing")
        }
    },
    CheckCase(name: "yarnAndPaperBallProduceChirpingPounces") {
        let mood = CatMood()
        let yarnReaction = CatReactionResolver.resolve(.yarn, mood: mood)
        let paperBallReaction = CatReactionResolver.resolve(.paperBall, mood: mood)
        let expected = CatReaction(activity: .pouncing, expression: .chirp)

        guard yarnReaction == expected, paperBallReaction == expected else {
            throw CheckFailure(description: "yarn and paper ball should trigger chirping pounces")
        }
    },
    CheckCase(name: "featherProducesLookingAroundReaction") {
        let reaction = CatReactionResolver.resolve(.feather, mood: CatMood())

        guard reaction == CatReaction(activity: .lookingAround, expression: .chirp) else {
            throw CheckFailure(description: "feather should trigger a chirping look-around")
        }
    },
    CheckCase(name: "treatProducesEatingReaction") {
        let reaction = CatReactionResolver.resolve(.treat, mood: CatMood())

        guard reaction == CatReaction(activity: .eating, expression: .purr) else {
            throw CheckFailure(description: "treat should trigger purring eating")
        }
    },
    CheckCase(name: "clickProducesBlinkingSittingReaction") {
        let reaction = CatReactionResolver.resolve(.click, mood: CatMood())

        guard reaction == CatReaction(activity: .sitting, expression: .blink) else {
            throw CheckFailure(description: "click should trigger blinking sitting")
        }
    },
    CheckCase(name: "storeRoundTripsPreferences") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let expected = PetState(
            personality: .curiousExplorer,
            isMuted: true,
            reducedMotion: true
        )

        store.save(expected)

        guard store.load() == expected else {
            throw CheckFailure(description: "saved state did not round-trip through UserDefaults")
        }
    },
    CheckCase(name: "storeRoundTripsCompletePetState") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let expected = PetState(
            personality: .dignifiedSenior,
            mood: CatMood(hunger: 0.8, affection: 0.4, energy: 0.2, playfulness: 0.9),
            isMuted: true,
            isPaused: true,
            clickThrough: true,
            reducedMotion: true,
            highContrast: true,
            catScale: 1.35,
            windowOrigin: ScreenRelativePoint(x: 0.82, y: 0.18),
            windowLevel: .floating
        )

        store.save(expected)

        guard store.load() == expected else {
            throw CheckFailure(description: "care, accessibility, scale, or placement state did not round-trip")
        }
    },
    CheckCase(name: "absentStoredDataReturnsSafeDefaults") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)

        guard store.load() == PetState() else {
            throw CheckFailure(description: "absent stored data did not return PetState defaults")
        }
    },
    CheckCase(name: "corruptStoredDataReturnsSafeDefaults") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        defaults.set(Data([0x00, 0xFF, 0x7F]), forKey: "pet-state")
        let store = PetStateStore(defaults: defaults)

        guard store.load() == PetState() else {
            throw CheckFailure(description: "corrupt stored data did not return PetState defaults")
        }
    },
    CheckCase(name: "partialStoredDataUsesSafeDefaults") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        defaults.set(Data(#"{"personality":"sleepyLoaf"}"#.utf8), forKey: "pet-state")
        let store = PetStateStore(defaults: defaults)
        var expected = PetState()
        expected.personality = .sleepyLoaf

        guard store.load() == expected else {
            throw CheckFailure(description: "missing fields in stored data did not use safe defaults")
        }
    },
    CheckCase(name: "encodingFailurePreservesLastValidState") {
        let defaults = UserDefaults(suiteName: "DesktopCatChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let valid = PetState(personality: .sleepyLoaf, catScale: 0.9)
        var invalid = valid
        invalid.mood.energy = .nan

        store.save(valid)
        store.save(invalid)

        guard store.load() == valid else {
            throw CheckFailure(description: "an encoding failure overwrote the last valid state")
        }
    },
    CheckCase(name: "positionIsClampedInsideVisibleFrame") {
        let frame = CGRect(x: 0, y: 0, width: 1_000, height: 700)
        let result = DesktopCatWindowController.clampedOrigin(
            CGPoint(x: 1_200, y: -50),
            windowSize: CGSize(width: 180, height: 180),
            visibleFrame: frame
        )

        guard result == CGPoint(x: 820, y: 0) else {
            throw CheckFailure(description: "expected out-of-bounds position to clamp to (820, 0), got \(result)")
        }
    },
    CheckCase(name: "oversizedWindowIsAnchoredToVisibleFrameOrigin") {
        let frame = CGRect(x: 40, y: 30, width: 100, height: 80)
        let result = DesktopCatWindowController.clampedOrigin(
            CGPoint(x: 70, y: 50),
            windowSize: CGSize(width: 180, height: 180),
            visibleFrame: frame
        )

        guard result == CGPoint(x: 40, y: 30) else {
            throw CheckFailure(description: "expected oversized window to anchor at visible-frame origin, got \(result)")
        }
    },
    CheckCase(name: "fullscreenClassificationRecognizesScreenCoveringWindow") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [WorkspaceWindow(frame: screen, isOnScreen: true, layer: 0)],
            screenFrames: [screen]
        )

        guard isFullscreen else {
            throw CheckFailure(description: "expected a visible layer-zero screen-covering window to be fullscreen")
        }
    },
    CheckCase(name: "fullscreenClassificationIgnoresNonCoveringOrNonContentWindows") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [
                WorkspaceWindow(frame: CGRect(x: 0, y: 0, width: 1_000, height: 700), isOnScreen: true, layer: 0),
                WorkspaceWindow(frame: screen, isOnScreen: false, layer: 0),
                WorkspaceWindow(frame: screen, isOnScreen: true, layer: 3)
            ],
            screenFrames: [screen]
        )

        guard !isFullscreen else {
            throw CheckFailure(description: "expected non-covering and non-content windows not to be fullscreen")
        }
    },
    CheckCase(name: "fullscreenClassificationHidesWhenDataIsUnavailable") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: nil,
            screenFrames: [screen]
        )

        guard isFullscreen else {
            throw CheckFailure(description: "expected unavailable fullscreen data to hide the cat")
        }
    }
]

@MainActor
private func selectedChecks(arguments: [String]) throws -> [CheckCase] {
    guard !arguments.isEmpty else { return checks }
    guard arguments.count == 2, arguments[0] == "--filter" else {
        throw CheckFailure(description: "usage: DesktopCatChecks [--filter <substring>]")
    }

    let filter = arguments[1]
    let selected = checks.filter { $0.name.contains(filter) }
    guard !selected.isEmpty else {
        throw CheckFailure(description: "no checks matched filter: \(filter)")
    }
    return selected
}

@MainActor
private func runChecks(arguments: [String]) -> Int32 {
    do {
        let selected = try selectedChecks(arguments: arguments)
        var failureCount = 0

        for check in selected {
            do {
                try check.run()
                print("PASS \(check.name)")
            } catch {
                failureCount += 1
                print("FAIL \(check.name): \(error)")
            }
        }

        print("SUMMARY \(selected.count - failureCount) passed, \(failureCount) failed")
        return failureCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE
    } catch {
        print("FAIL harness: \(error)")
        print("SUMMARY 0 passed, 1 failed")
        return EXIT_FAILURE
    }
}

exit(runChecks(arguments: Array(CommandLine.arguments.dropFirst())))
