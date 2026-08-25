import Darwin
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
