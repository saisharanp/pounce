import AppKit
import Darwin
import CoreGraphics
import PounceCore
import Foundation
import SwiftUI

private struct CheckCase {
    let name: String
    let run: () throws -> Void
}

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private struct CatInspectionGrid: View {
    private let samples: [(CatActivity, CatExpression)] = [
        (.sitting, .blink), (.loafing, .purr), (.walking, .sideEye),
        (.sleeping, .slowBlink), (.waking, .startled), (.stretching, .neutral),
        (.grooming, .neutral), (.kneading, .slowBlink), (.lookingAround, .chirp),
        (.pouncing, .chirp), (.zooming, .startled), (.hiding, .neutral),
        (.peeking, .sideEye), (.eating, .purr), (.sunbathing, .meow)
    ]

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<5, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let index = row * 3 + column
                        let sample = samples[index]
                        VStack(spacing: 2) {
                            OrangeTabbyShape(
                                pose: CatPose(
                                    activity: sample.0,
                                    expression: sample.1,
                                    phase: sample.1 == .blink || sample.1 == .slowBlink
                                        ? true
                                        : index.isMultiple(of: 2),
                                    motionAllowed: true
                                ),
                                highContrast: index == 10
                            )
                            .frame(width: 120, height: 120)
                            Text("\(sample.0.rawValue) · \(sample.1.rawValue)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
    }
}

@MainActor
private func nativeSnapshot<Content: View>(
    of content: Content,
    size: CGSize
) -> NSImage? {
    let hostingView = NSHostingView(rootView: content)
    hostingView.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(
        contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()
    guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        return nil
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
    let image = NSImage(size: size)
    image.addRepresentation(bitmap)
    return image
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
    CheckCase(name: "secondClickReachesMeowThroughViewModel") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))

        model.handle(.click)
        guard model.expression == .blink else {
            throw CheckFailure(description: "the first contextual click did not blink")
        }

        model.handle(.click)
        guard model.expression == .meow else {
            throw CheckFailure(description: "the second contextual click did not reach meow")
        }
    },
    CheckCase(name: "thirdClickReachesStartledThroughViewModel") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))

        model.handle(.click)
        model.handle(.click)
        model.handle(.click)

        guard model.activity == .lookingAround, model.expression == .startled else {
            throw CheckFailure(description: "the third contextual click did not reach a startled look-around")
        }
    },
    CheckCase(name: "repeatedIdenticalInteractionsAdvanceReactionNonce") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))
        let initialNonce = model.reactionNonce

        model.handle(.gentlePet)
        let firstNonce = model.reactionNonce
        model.handle(.gentlePet)
        let secondNonce = model.reactionNonce

        guard initialNonce < firstNonce, firstNonce < secondNonce else {
            throw CheckFailure(
                description: "identical direct reactions did not publish monotonically increasing animation nonces"
            )
        }
    },
    CheckCase(name: "interactionPreemptsIdleActivity") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            scheduler: CatScheduler(randomIndex: { _ in 0 })
        )

        model.scheduleIdleActivity(now: Date(timeIntervalSince1970: 12 * 60 * 60))
        model.handle(.gentlePet)

        guard model.activity == .kneading else {
            throw CheckFailure(description: "gentle petting did not preempt the idle activity with kneading")
        }
        guard model.expression == .slowBlink else {
            throw CheckFailure(description: "gentle petting did not synchronously select a slow blink")
        }
    },
    CheckCase(name: "pausedModelDoesNotScheduleNewIdleActivity") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            scheduler: CatScheduler(randomIndex: { _ in 0 })
        )

        model.setPaused(true)
        model.scheduleIdleActivity(now: Date(timeIntervalSince1970: 12 * 60 * 60))

        guard model.activity == .sitting, model.state.isPaused else {
            throw CheckFailure(description: "a paused model scheduled a new idle activity")
        }
    },
    CheckCase(name: "lifecycleEligibilitySuspendsIdleWorkWhenNotDisplayable") {
        guard AppCoordinator.shouldScheduleIdle(
            isVisible: true,
            isPaused: false,
            isFullscreenActive: false
        ) else {
            throw CheckFailure(description: "a visible, unpaused cat outside fullscreen was not eligible for idle work")
        }

        let suspendedStates = [
            (false, false, false),
            (true, true, false),
            (true, false, true)
        ]
        for (isVisible, isPaused, isFullscreenActive) in suspendedStates {
            guard !AppCoordinator.shouldScheduleIdle(
                isVisible: isVisible,
                isPaused: isPaused,
                isFullscreenActive: isFullscreenActive
            ) else {
                throw CheckFailure(description: "hidden, paused, or fullscreen state left idle work eligible")
            }
        }
    },
    CheckCase(name: "attentionLevelsUseApprovedIdleIntervals") {
        guard AppCoordinator.idleInterval(for: .calm) == 20...35,
              AppCoordinator.idleInterval(for: .balanced) == 10...20,
              AppCoordinator.idleInterval(for: .lively) == 5...12 else {
            throw CheckFailure(description: "attention levels did not use the approved idle intervals")
        }
    },
    CheckCase(name: "coordinatorDirectReactionReplacesPendingIdleSchedule") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let workspaceObserver = WorkspaceObserver(
            windowDataProvider: { [] },
            screenFrameProvider: { [screen] }
        )
        let coordinator = AppCoordinator(
            store: PetStateStore(defaults: defaults),
            workspaceObserver: workspaceObserver
        )

        coordinator.start()
        let initialSchedule = coordinator.idleScheduleRevision
        coordinator.menuController.handle(.gentlePet)
        let reactionSchedule = coordinator.idleScheduleRevision
        coordinator.menuController.setAttentionLevel(.lively)
        let attentionSchedule = coordinator.idleScheduleRevision

        guard coordinator.hasStarted,
              initialSchedule > 0,
              reactionSchedule == initialSchedule + 1,
              attentionSchedule == reactionSchedule + 1 else {
            throw CheckFailure(
                description: "direct reactions or attention changes did not replace the coordinator idle schedule"
            )
        }
    },
    CheckCase(name: "elapsedCareUpdateIsGentleAndNeverPunishes") {
        let updated = CatMood().applyingElapsedCare(seconds: 24 * 60 * 60)

        guard updated.hunger > 0.25,
              updated.hunger < 0.5,
              updated.affection >= 0.65,
              updated.energy >= 0.65,
              updated.playfulness >= 0.65 else {
            throw CheckFailure(description: "elapsed care update was not gentle and non-punitive")
        }
    },
    CheckCase(name: "launchRestorationAppliesPersistedElapsedCare") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let firstLaunch = Date(timeIntervalSince1970: 1_000_000)
        let relaunch = firstLaunch.addingTimeInterval(24 * 60 * 60)
        let original = PetState(
            mood: CatMood(hunger: 0.25, affection: 0.65, energy: 0.65, playfulness: 0.65),
            lastCareUpdate: firstLaunch.addingTimeInterval(-24 * 60 * 60)
        )
        store.save(original)

        let launchModel = CatViewModel(store: store)
        launchModel.restoreElapsedCare(now: firstLaunch)
        let afterLaunch = store.load()

        guard afterLaunch.lastCareUpdate == firstLaunch,
              afterLaunch.mood.hunger > original.mood.hunger else {
            throw CheckFailure(description: "launch restoration did not apply persisted elapsed care")
        }

        let relaunchModel = CatViewModel(store: store)
        relaunchModel.restoreElapsedCare(now: relaunch)
        let afterRelaunch = store.load()

        guard afterRelaunch.lastCareUpdate == relaunch,
              afterRelaunch.mood.hunger > afterLaunch.mood.hunger else {
            throw CheckFailure(description: "relaunch did not apply care since the persisted launch timestamp")
        }
    },
    CheckCase(name: "selectedToyIsTransientAndCompletesEveryInteraction") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let model = CatViewModel(store: store)
        let expectedReactions: [(CatToy, CatActivity, CatExpression)] = [
            (.laser, .pouncing, .neutral),
            (.yarn, .pouncing, .chirp),
            (.feather, .lookingAround, .chirp),
            (.paperBall, .pouncing, .chirp),
            (.treat, .eating, .purr)
        ]

        for (toy, expectedActivity, expectedExpression) in expectedReactions {
            model.selectToy(toy)
            guard model.selectedToy == toy else {
                throw CheckFailure(description: "\(toy) did not become the transient selected toy")
            }
            model.completeSelectedToy()
            guard model.selectedToy == nil,
                  model.activity == expectedActivity,
                  model.expression == expectedExpression else {
                throw CheckFailure(description: "\(toy) did not complete with its approved reaction")
            }
        }

        guard store.load() == PetState() else {
            throw CheckFailure(description: "transient toy selection leaked into persisted pet state")
        }
    },
    CheckCase(name: "treatActionSelectsEatingReaction") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))

        model.handle(.treat)

        guard model.activity == .eating else {
            throw CheckFailure(description: "the treat action did not select the eating reaction")
        }
    },
    CheckCase(name: "proceduralSoundsHonorMuteAndClampedVolume") {
        guard CatSoundController.playbackPlan(
            for: .purr,
            isMuted: true,
            volume: 0.8
        ) == nil else {
            throw CheckFailure(description: "muted sound created a playback plan")
        }

        guard let plan = CatSoundController.playbackPlan(
            for: .play,
            isMuted: false,
            volume: 3
        ) else {
            throw CheckFailure(description: "enabled sound did not create a playback plan")
        }
        guard plan.volume == 1,
              plan.data.count > 44,
              String(data: plan.data.prefix(4), encoding: .ascii) == "RIFF",
              String(data: plan.data.dropFirst(8).prefix(4), encoding: .ascii) == "WAVE" else {
            throw CheckFailure(description: "procedural playback was not a clamped local WAV tone")
        }

        let distinctTones = Set(CatSoundKind.allCases.map {
            CatSoundController.toneData(for: $0)
        })
        guard distinctTones.count == CatSoundKind.allCases.count else {
            throw CheckFailure(description: "one or more approved cat responses shared the same tone")
        }
    },
    CheckCase(name: "catVoiceUsesMeowContourAndPurrPulseTrain") {
        if ProcessInfo.processInfo.environment["POUNCE_DUMP_SOUNDS"] == "1" {
            let directory = URL(fileURLWithPath: "/tmp/pounce-sounds")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for kind in CatSoundKind.allCases {
                try CatSoundController.toneData(for: kind)
                    .write(to: directory.appendingPathComponent("\(kind.rawValue).wav"))
            }
        }

        let meow = try wavPCM(CatSoundController.toneData(for: .meow))
        let purr = try wavPCM(CatSoundController.toneData(for: .purr))
        let meowDuration = Double(meow.samples.count) / Double(meow.sampleRate)
        let purrDuration = Double(purr.samples.count) / Double(purr.sampleRate)
        guard meowDuration >= 0.45 else {
            throw CheckFailure(description: "meow lasted \(meowDuration)s; a cat voice needs a full miaow")
        }
        guard purrDuration >= 0.7 else {
            throw CheckFailure(description: "purr lasted \(purrDuration)s; a cat rumble has to settle in")
        }

        let thirds = zeroCrossingRatesByThird(meow.samples)
        guard thirds[1] > thirds[0], thirds[1] > thirds[2] else {
            throw CheckFailure(description: "meow pitch did not rise then fall like a cat miaow")
        }

        let pulses = pulseCount(purr.samples, sampleRate: purr.sampleRate)
        guard pulses >= 12 else {
            throw CheckFailure(description: "purr had \(pulses) pulses; cats rumble at ~25 Hz")
        }
    },
    CheckCase(name: "interactionsRouteEveryApprovedSoundResponse") {
        let mappings: [(CatInteraction, CatReaction, CatSoundKind)] = [
            (.gentlePet, CatReaction(activity: .kneading, expression: .slowBlink), .purr),
            (.click, CatReaction(activity: .sitting, expression: .meow), .meow),
            (.feather, CatReaction(activity: .lookingAround, expression: .chirp), .chirp),
            (.laser, CatReaction(activity: .pouncing, expression: .neutral), .play),
            (.treat, CatReaction(activity: .eating, expression: .purr), .eat)
        ]

        for (interaction, reaction, expected) in mappings {
            guard CatSoundController.sound(for: interaction, reaction: reaction) == expected else {
                throw CheckFailure(description: "\(expected.rawValue) did not map from its approved response")
            }
        }
    },
    CheckCase(name: "menuControllerRoutesActionsAndPersistsSettings") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let model = CatViewModel(store: store)
        var visibilityChanges: [Bool] = []
        var clickThroughChanges: [Bool] = []
        var levelChanges: [PetWindowLevel] = []
        let controls = MenuBarController(
            viewModel: model,
            onSetVisibility: { visibilityChanges.append($0) },
            onSetClickThrough: { clickThroughChanges.append($0) },
            onSetWindowLevel: { levelChanges.append($0) }
        )

        controls.hide()
        controls.summon()
        controls.togglePause()
        controls.toggleMuted()
        controls.setClickThrough(true)
        controls.setWindowLevel(.floating)
        controls.setPersonality(.curiousExplorer)
        controls.setAttentionLevel(.lively)
        controls.setHideInFullscreen(false)
        controls.setSoundVolume(-0.5)
        controls.selectToy(.treat)
        controls.completeSelectedToy()

        guard visibilityChanges == [false, true],
              clickThroughChanges == [true],
              levelChanges == [.floating] else {
            throw CheckFailure(description: "menu actions did not reach their explicit window callbacks")
        }
        guard model.state.isPaused,
              model.state.isMuted,
              model.state.clickThrough,
              model.state.windowLevel == .floating,
              model.state.personality == .curiousExplorer,
              model.state.attentionLevel == .lively,
              !model.state.hideInFullscreen,
              model.state.soundVolume == 0 else {
            throw CheckFailure(description: "menu controls did not update the complete persisted state")
        }
        guard model.activity == .eating, model.selectedToy == nil else {
            throw CheckFailure(description: "the treat control did not complete through the model API")
        }
        guard store.load() == model.state else {
            throw CheckFailure(description: "menu-driven settings did not survive persistence")
        }
    },
    CheckCase(name: "keyboardActionsAreCompleteAndDiscoverable") {
        let shortcuts = PounceKeyboardAction.allCases.map {
            ($0.title, $0.key, $0.modifierDescription)
        }
        let expected = [
            ("Summon or Hide", "C", "Command-Shift"),
            ("Pause or Resume", "P", "Command-Shift"),
            ("Mute or Unmute", "M", "Command-Shift")
        ]

        guard shortcuts.count == expected.count else {
            throw CheckFailure(description: "the discoverable shortcut list was incomplete")
        }
        for (actual, expectedShortcut) in zip(shortcuts, expected) {
            guard actual.0 == expectedShortcut.0,
                  actual.1 == expectedShortcut.1,
                  actual.2 == expectedShortcut.2 else {
                throw CheckFailure(description: "keyboard action \(actual.0) had the wrong discoverable shortcut")
            }
        }
    },
    CheckCase(name: "systemHotKeysMatchDiscoverableShortcuts") {
        let hotKeys = PounceSystemHotKey.allCases.map {
            ($0.action, $0.keyCode, $0.modifiers)
        }
        let expected: [(PounceKeyboardAction, UInt32, UInt32)] = [
            (.summonOrHide, 8, PounceSystemHotKey.commandShiftModifiers),
            (.pauseOrResume, 35, PounceSystemHotKey.commandShiftModifiers),
            (.muteOrUnmute, 46, PounceSystemHotKey.commandShiftModifiers)
        ]

        guard hotKeys.count == expected.count else {
            throw CheckFailure(description: "the system hot-key registry was incomplete")
        }
        for (actual, expectedHotKey) in zip(hotKeys, expected) {
            guard actual.0 == expectedHotKey.0,
                  actual.1 == expectedHotKey.1,
                  actual.2 == expectedHotKey.2 else {
                throw CheckFailure(description: "a system hot key did not match its advertised shortcut")
            }
        }
    },
    CheckCase(name: "toyOverlayRendersEveryApprovedControl") {
        guard CatToy.allCases.map(\.displayName) == [
            "Laser", "Yarn", "Feather", "Paper Ball", "Treat"
        ] else {
            throw CheckFailure(description: "the toy overlay did not expose all five approved labels")
        }

        for toy in CatToy.allCases {
            let renderer = ImageRenderer(
                content: ToyOverlayView(
                    selectedToy: toy,
                    reducedMotion: true,
                    onCompleted: {}
                )
                .frame(width: 180, height: 180)
            )
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let representation = image.tiffRepresentation,
                  representation.count > 500 else {
                throw CheckFailure(description: "\(toy.displayName) did not render a visible native overlay")
            }
        }
    },
    CheckCase(name: "catViewRendersTransientToyOverlay") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))
        let controller = MenuBarController(viewModel: model)
        let plainRenderer = ImageRenderer(
            content: CatView(viewModel: model, controller: controller)
                .frame(width: 180, height: 180)
        )
        plainRenderer.scale = 2
        guard let plain = plainRenderer.nsImage?.tiffRepresentation else {
            throw CheckFailure(description: "the base cat view did not render")
        }

        model.selectToy(.treat)
        let toyRenderer = ImageRenderer(
            content: CatView(viewModel: model, controller: controller)
                .frame(width: 180, height: 180)
        )
        toyRenderer.scale = 2
        guard let withToy = toyRenderer.nsImage?.tiffRepresentation,
              withToy != plain else {
            throw CheckFailure(description: "the selected treat was not composed over the cat view")
        }
    },
    CheckCase(name: "menuAndSettingsSurfacesRenderNatively") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let controls = MenuBarController(
            viewModel: CatViewModel(store: PetStateStore(defaults: defaults))
        )
        guard let settingsImage = nativeSnapshot(
            of: SettingsView(controller: controls),
            size: CGSize(width: 480, height: 780)
        ),
            let settings = settingsImage.tiffRepresentation,
            settings.count > 2_000,
            let menuImage = nativeSnapshot(
                of: MenuBarContent(controller: controls),
                size: CGSize(width: 330, height: 780)
            ),
            let menu = menuImage.tiffRepresentation,
            menu.count > 2_000 else {
            throw CheckFailure(description: "menu-bar or settings controls did not render visibly")
        }

        if let snapshotPath = ProcessInfo.processInfo.environment["DESKTOP_CAT_CONTROLS_SNAPSHOT_PATH"] {
            let image = NSImage(size: CGSize(width: 846, height: 816))
            image.lockFocus()
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: image.size).fill()
            menuImage.draw(at: CGPoint(x: 18, y: 18), from: .zero, operation: .copy, fraction: 1)
            settingsImage.draw(at: CGPoint(x: 348, y: 18), from: .zero, operation: .copy, fraction: 1)
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CheckFailure(description: "the control inspection image could not be encoded")
            }
            try png.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
            print("SNAPSHOT \(snapshotPath)")
        }
    },
    CheckCase(name: "viewModelRetainsTwoRecentIdleActivities") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            scheduler: CatScheduler(randomIndex: { _ in 0 })
        )
        let noon = Date(timeIntervalSince1970: 12 * 60 * 60)

        model.scheduleIdleActivity(now: noon)
        model.scheduleIdleActivity(now: noon)
        model.scheduleIdleActivity(now: noon)

        guard model.recentIdleActivities == [.loafing, .walking] else {
            throw CheckFailure(
                description: "expected only the latest two idle activities, got \(model.recentIdleActivities)"
            )
        }
    },
    CheckCase(name: "viewModelPersistsStateChanges") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let model = CatViewModel(store: store)

        model.updateState {
            $0.reducedMotion = true
            $0.highContrast = true
            $0.catScale = 1.3
        }

        let restored = store.load()
        guard restored == model.state else {
            throw CheckFailure(description: "the model's state change was not persisted")
        }
        guard restored.reducedMotion, restored.highContrast, restored.catScale == 1.3 else {
            throw CheckFailure(description: "the persisted accessibility and scale values were incomplete")
        }
    },
    CheckCase(name: "viewModelUsesInjectedInitialRenderingState") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let expected = PetState(reducedMotion: true, highContrast: true, catScale: 1.25)
        let model = CatViewModel(
            store: PetStateStore(defaults: defaults),
            initialState: expected
        )

        guard model.state == expected else {
            throw CheckFailure(description: "the panel's initial accessibility and scale state was not adopted")
        }
    },
    CheckCase(name: "primaryActivitiesUseDistinctCatPoses") {
        let poses = CatActivity.allCases.map {
            CatPose(activity: $0, expression: .neutral, phase: false, motionAllowed: false)
        }

        guard Set(poses).count == CatActivity.allCases.count else {
            throw CheckFailure(description: "one or more primary activities collapsed to the same generic pose")
        }
    },
    CheckCase(name: "expressionsUseDistinctFacePoses") {
        let expressions: [CatExpression] = [
            .neutral, .blink, .slowBlink, .purr, .chirp, .meow, .sideEye, .startled
        ]
        let poses = expressions.map {
            CatPose(activity: .sitting, expression: $0, phase: false, motionAllowed: false)
        }

        guard Set(poses).count == expressions.count else {
            throw CheckFailure(description: "one or more expressions collapsed to the same face pose")
        }
    },
    CheckCase(name: "disabledMotionUsesStablePose") {
        let activeStart = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: false,
            motionAllowed: true
        )
        let activeEnd = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: true,
            motionAllowed: true
        )
        let staticStart = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: false,
            motionAllowed: false
        )
        let staticEnd = CatPose(
            activity: .walking,
            expression: .neutral,
            phase: true,
            motionAllowed: false
        )

        guard activeStart != activeEnd else {
            throw CheckFailure(description: "normal motion did not produce a bounded phase change")
        }
        guard staticStart == staticEnd else {
            throw CheckFailure(description: "reduced-motion or paused rendering still changed by phase")
        }
    },
    CheckCase(name: "normalBlinkClosesThenEndsOpen") {
        let start = CatPose(
            activity: .sitting,
            expression: .blink,
            phase: false,
            motionAllowed: true
        )
        let closed = CatPose(
            activity: .sitting,
            expression: .blink,
            phase: true,
            motionAllowed: true
        )
        let end = CatPose(
            activity: .sitting,
            expression: .blink,
            phase: false,
            motionAllowed: true
        )

        guard start.eyeScaleY == 1, closed.eyeScaleY < 0.2, end.eyeScaleY == 1 else {
            throw CheckFailure(description: "normal blink did not resolve open, closed, then open eye poses")
        }
    },
    CheckCase(name: "normalSlowBlinkClosesThenEndsOpen") {
        let start = CatPose(
            activity: .kneading,
            expression: .slowBlink,
            phase: false,
            motionAllowed: true
        )
        let closed = CatPose(
            activity: .kneading,
            expression: .slowBlink,
            phase: true,
            motionAllowed: true
        )
        let end = CatPose(
            activity: .kneading,
            expression: .slowBlink,
            phase: false,
            motionAllowed: true
        )

        guard start.eyeScaleY == 1, closed.eyeScaleY < 0.4, end.eyeScaleY == 1 else {
            throw CheckFailure(description: "normal slow blink did not resolve open, closed, then open eye poses")
        }
    },
    CheckCase(name: "slowBlinkUsesSlowerBoundedAnimationTiming") {
        let blink = CatAnimationTiming(expression: .blink)
        let slowBlink = CatAnimationTiming(expression: .slowBlink)

        guard slowBlink.closingMilliseconds > blink.closingMilliseconds,
              slowBlink.openingMilliseconds > blink.openingMilliseconds,
              slowBlink.totalMilliseconds > blink.totalMilliseconds,
              slowBlink.totalMilliseconds <= 2_000 else {
            throw CheckFailure(description: "slow-blink timing was not slower than blink while remaining bounded")
        }
    },
    CheckCase(name: "animatedCatPosesStayInsideVisualBounds") {
        let expressions: [CatExpression] = [
            .neutral, .blink, .slowBlink, .purr, .chirp, .meow, .sideEye, .startled
        ]

        for activity in CatActivity.allCases {
            for expression in expressions {
                for phase in [false, true] {
                    let pose = CatPose(
                        activity: activity,
                        expression: expression,
                        phase: phase,
                        motionAllowed: true
                    )
                    guard abs(pose.bodyX) <= 12,
                          pose.bodyY >= -4, pose.bodyY <= 15,
                          pose.bodyScaleX >= 0.75, pose.bodyScaleX <= 1.2,
                          pose.bodyScaleY >= 0.75, pose.bodyScaleY <= 1.1,
                          abs(pose.bodyRotation) <= 12,
                          abs(pose.headRotation) <= 45,
                          abs(pose.tailRotation) <= 35,
                          pose.opacity >= 0.3, pose.opacity <= 1 else {
                        throw CheckFailure(
                            description: "\(activity.rawValue)/\(expression.rawValue) exceeded the cat's visual bounds"
                        )
                    }
                }
            }
        }
    },
    CheckCase(name: "tapOnCatMapsToClick") {
        let interaction = CatGestureInterpreter.interaction(
            translation: CGSize(width: 1, height: 1),
            duration: 0.15,
            recentContactCount: 1
        )

        guard case .click = interaction else {
            throw CheckFailure(description: "a stationary contact did not map to a click")
        }
    },
    CheckCase(name: "slowDragOnCatMapsToGentlePet") {
        let interaction = CatGestureInterpreter.interaction(
            translation: CGSize(width: 40, height: 5),
            duration: 1.2,
            recentContactCount: 1
        )

        guard case .gentlePet = interaction else {
            throw CheckFailure(description: "a deliberate slow drag did not map to gentle petting")
        }
    },
    CheckCase(name: "fastDragOnCatMapsToHurriedAttention") {
        let interaction = CatGestureInterpreter.interaction(
            translation: CGSize(width: 80, height: 0),
            duration: 0.1,
            recentContactCount: 1
        )

        guard case .hurriedAttention = interaction else {
            throw CheckFailure(description: "a fast drag did not map to mild hurried-attention feedback")
        }
    },
    CheckCase(name: "repeatedCatContactMapsToHurriedAttention") {
        let interaction = CatGestureInterpreter.interaction(
            translation: .zero,
            duration: 0.2,
            recentContactCount: 3
        )

        guard case .hurriedAttention = interaction else {
            throw CheckFailure(description: "repeated contact did not map to mild hurried-attention feedback")
        }
    },
    CheckCase(name: "orangeTabbyRendersVisibleNativeLayers") {
        let pose = CatPose(
            activity: .sitting,
            expression: .slowBlink,
            phase: false,
            motionAllowed: false
        )
        let renderer = ImageRenderer(
            content: OrangeTabbyShape(pose: pose, highContrast: false)
                .frame(width: 160, height: 160)
        )
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let representation = image.tiffRepresentation,
              representation.count > 1_000 else {
            throw CheckFailure(description: "the layered orange tabby did not produce a visible rendered image")
        }

        if let snapshotPath = ProcessInfo.processInfo.environment["DESKTOP_CAT_SNAPSHOT_PATH"] {
            let inspectionRenderer = ImageRenderer(content: CatInspectionGrid())
            inspectionRenderer.scale = 2
            guard let inspectionImage = inspectionRenderer.nsImage,
                  let tiff = inspectionImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CheckFailure(description: "the pose inspection grid could not be encoded")
            }
            try png.write(to: URL(fileURLWithPath: snapshotPath), options: .atomic)
            print("SNAPSHOT \(snapshotPath)")
        }
    },
    CheckCase(name: "catHitAreaLeavesTransparentPanelCornersDraggable") {
        let bounds = CGRect(x: 0, y: 0, width: 160, height: 160)

        guard CatHitArea.contains(CGPoint(x: 80, y: 88), in: bounds) else {
            throw CheckFailure(description: "the illustrated cat center was not interactive")
        }
        guard !CatHitArea.contains(CGPoint(x: 5, y: 5), in: bounds),
              !CatHitArea.contains(CGPoint(x: 155, y: 155), in: bounds) else {
            throw CheckFailure(description: "transparent panel corners intercepted cat gestures")
        }
    },
    CheckCase(name: "storeRoundTripsPreferences") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
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
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
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
            windowDisplayIdentifier: "42",
            windowLevel: .floating
        )

        store.save(expected)

        guard store.load() == expected else {
            throw CheckFailure(description: "care, accessibility, scale, or placement state did not round-trip")
        }
    },
    CheckCase(name: "legacyPlacementDecodesWithoutDisplayIdentifier") {
        let original = PetState(windowOrigin: ScreenRelativePoint(x: 0.82, y: 0.18))
        let encoded = try JSONEncoder().encode(original)
        guard var legacyPayload = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw CheckFailure(description: "could not create a legacy placement fixture")
        }
        legacyPayload.removeValue(forKey: "windowDisplayIdentifier")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload)
        let decoded = try JSONDecoder().decode(PetState.self, from: legacyData)

        guard decoded.windowOrigin == original.windowOrigin,
              decoded.windowDisplayIdentifier == nil else {
            throw CheckFailure(description: "legacy placement did not safely default its missing display identifier")
        }
    },
    CheckCase(name: "taskSevenPreferencesRoundTripAndClampVolume") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)
        let expected = PetState(
            soundVolume: 1.4,
            hideInFullscreen: false,
            attentionLevel: .lively
        )

        store.save(expected)
        let restored = store.load()

        guard restored.soundVolume == 1 else {
            throw CheckFailure(description: "sound volume was not clamped to the persisted 0...1 range")
        }
        guard !restored.hideInFullscreen, restored.attentionLevel == .lively else {
            throw CheckFailure(description: "fullscreen or attention preferences did not round-trip")
        }
    },
    CheckCase(name: "legacyStateUsesSafeTaskSevenDefaults") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        defaults.set(
            Data(#"{"personality":"sleepyLoaf","soundVolume":-3,"attentionLevel":"unknown"}"#.utf8),
            forKey: "pet-state"
        )
        let restored = PetStateStore(defaults: defaults).load()

        guard restored.personality == .sleepyLoaf else {
            throw CheckFailure(description: "an invalid new preference discarded valid legacy state")
        }
        guard restored.soundVolume == 0,
              restored.hideInFullscreen,
              restored.attentionLevel == .balanced else {
            throw CheckFailure(description: "legacy state did not receive safe task-seven preference defaults")
        }
    },
    CheckCase(name: "absentStoredDataReturnsSafeDefaults") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let store = PetStateStore(defaults: defaults)

        guard store.load() == PetState() else {
            throw CheckFailure(description: "absent stored data did not return PetState defaults")
        }
    },
    CheckCase(name: "corruptStoredDataReturnsSafeDefaults") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        defaults.set(Data([0x00, 0xFF, 0x7F]), forKey: "pet-state")
        let store = PetStateStore(defaults: defaults)

        guard store.load() == PetState() else {
            throw CheckFailure(description: "corrupt stored data did not return PetState defaults")
        }
    },
    CheckCase(name: "partialStoredDataUsesSafeDefaults") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        defaults.set(Data(#"{"personality":"sleepyLoaf"}"#.utf8), forKey: "pet-state")
        let store = PetStateStore(defaults: defaults)
        var expected = PetState()
        expected.personality = .sleepyLoaf

        guard store.load() == expected else {
            throw CheckFailure(description: "missing fields in stored data did not use safe defaults")
        }
    },
    CheckCase(name: "encodingFailurePreservesLastValidState") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
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
        let result = PounceWindowController.clampedOrigin(
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
        let result = PounceWindowController.clampedOrigin(
            CGPoint(x: 70, y: 50),
            windowSize: CGSize(width: 180, height: 180),
            visibleFrame: frame
        )

        guard result == CGPoint(x: 40, y: 30) else {
            throw CheckFailure(description: "expected oversized window to anchor at visible-frame origin, got \(result)")
        }
    },
    CheckCase(name: "savedPlacementRestoresOnMatchingConnectedDisplay") {
        let primary = PounceDisplay(
            identifier: "primary",
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        let secondary = PounceDisplay(
            identifier: "secondary",
            visibleFrame: CGRect(x: -1_280, y: 0, width: 1_280, height: 1_024)
        )
        let origin = PounceWindowController.restoredOrigin(
            relativeOrigin: ScreenRelativePoint(x: 0.5, y: 0.25),
            windowSize: CGSize(width: 180, height: 180),
            savedDisplayIdentifier: "secondary",
            displays: [primary, secondary],
            primaryDisplayIdentifier: "primary"
        )

        guard origin == CGPoint(x: -730, y: 211) else {
            throw CheckFailure(description: "saved placement did not restore on its connected secondary display")
        }
    },
    CheckCase(name: "missingSavedDisplayFallsBackToPrimaryPlacement") {
        let primary = PounceDisplay(
            identifier: "primary",
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        let secondary = PounceDisplay(
            identifier: "secondary",
            visibleFrame: CGRect(x: -1_280, y: 0, width: 1_280, height: 1_024)
        )
        let origin = PounceWindowController.restoredOrigin(
            relativeOrigin: ScreenRelativePoint(x: 0.5, y: 0.25),
            windowSize: CGSize(width: 180, height: 180),
            savedDisplayIdentifier: "disconnected",
            displays: [primary, secondary],
            primaryDisplayIdentifier: "primary"
        )

        guard origin == CGPoint(x: 630, y: 180) else {
            throw CheckFailure(description: "a disconnected display did not fall back to primary placement")
        }
    },
    CheckCase(name: "fullscreenHidingPreferenceControlsVisibilityPolicy") {
        guard !PounceWindowController.shouldShow(
            requestedVisibility: true,
            isFullscreenActive: true,
            hideInFullscreen: true
        ) else {
            throw CheckFailure(description: "fullscreen hiding did not suppress a requested cat window")
        }
        guard PounceWindowController.shouldShow(
            requestedVisibility: true,
            isFullscreenActive: true,
            hideInFullscreen: false
        ) else {
            throw CheckFailure(description: "disabling fullscreen hiding did not reveal the requested cat window")
        }
        guard !PounceWindowController.shouldShow(
            requestedVisibility: false,
            isFullscreenActive: false,
            hideInFullscreen: false
        ) else {
            throw CheckFailure(description: "fullscreen preference overrode an explicit hide action")
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
    CheckCase(name: "fullscreenClassificationAllowsSmallFrameTolerance") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let nearlyEqualWindow = CGRect(x: 0.5, y: -0.5, width: 1_440, height: 900)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [WorkspaceWindow(frame: nearlyEqualWindow, isOnScreen: true, layer: 0)],
            screenFrames: [screen]
        )

        guard isFullscreen else {
            throw CheckFailure(description: "expected a window within frame tolerance to be fullscreen")
        }
    },
    CheckCase(name: "fullscreenClassificationRejectsSpanningWindow") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let spanningWindow = CGRect(x: -100, y: -100, width: 3_200, height: 1_200)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [WorkspaceWindow(frame: spanningWindow, isOnScreen: true, layer: 0)],
            screenFrames: [screen]
        )

        guard !isFullscreen else {
            throw CheckFailure(description: "expected a spanning window not to be classified as fullscreen")
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
    },
    CheckCase(name: "fullscreenClassificationUsesCGFramesForVerticallyArrangedDisplays") {
        let primary = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let upperSecondary = CGRect(x: 0, y: 900, width: 1_280, height: 1_024)
        let isFullscreen = WorkspaceObserver.isFullscreenAppActive(
            windowData: [WorkspaceWindow(frame: upperSecondary, isOnScreen: true, layer: 0)],
            screenFrames: [primary, upperSecondary]
        )

        guard isFullscreen else {
            throw CheckFailure(
                description: "Core Graphics bounds on a vertically arranged secondary display were not recognized"
            )
        }
    },
    CheckCase(name: "selfFrontmostWorkspaceStateRemainsConservativelyHidden") {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let observer = WorkspaceObserver(
            windowDataProvider: { [] },
            screenFrameProvider: { [screen] },
            isCurrentProcessFrontmostProvider: { true }
        )

        guard observer.isFullscreenAppActive else {
            throw CheckFailure(
                description: "self-frontmost workspace state treated an empty external window list as safe"
            )
        }
    },
    CheckCase(name: "workspaceObserverRefreshesWhenFullscreenAppHides") {
        let notificationCenter = NotificationCenter()
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        var windowData: [WorkspaceWindow]? = [
            WorkspaceWindow(frame: screen, isOnScreen: true, layer: 0)
        ]
        let observer = WorkspaceObserver(
            windowDataProvider: { windowData },
            screenFrameProvider: { [screen] },
            notificationCenter: notificationCenter
        )

        guard observer.isFullscreenAppActive else {
            throw CheckFailure(description: "the fullscreen fixture did not initialize conservatively")
        }

        windowData = []
        notificationCenter.post(name: NSWorkspace.didHideApplicationNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        guard !observer.isFullscreenAppActive else {
            throw CheckFailure(description: "hiding the fullscreen application did not refresh workspace state")
        }
    },
    CheckCase(name: "extendedPointerInteractionsResolveDistinctReactions") {
        let mood = CatMood()
        let expected: [(CatInteraction, CatReaction)] = [
            (.doubleClick, CatReaction(activity: .pouncing, expression: .chirp)),
            (.scrollUp, CatReaction(activity: .lookingAround, expression: .chirp)),
            (.scrollDown, CatReaction(activity: .loafing, expression: .slowBlink)),
            (.secondaryClick, CatReaction(activity: .sitting, expression: .sideEye))
        ]
        for (interaction, reaction) in expected {
            guard CatReactionResolver.resolve(interaction, mood: mood) == reaction else {
                throw CheckFailure(description: "interaction (interaction) resolved to the wrong reaction")
            }
        }
    },
    CheckCase(name: "screenTimeCalculatorClipsAndPromptsSessions") {
        let start = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        let sessions = [
            ScreenTimeSession(startedAt: Date(timeIntervalSince1970: 900), endedAt: Date(timeIntervalSince1970: 1_100)),
            ScreenTimeSession(startedAt: Date(timeIntervalSince1970: 1_500), endedAt: nil)
        ]
        let summary = ScreenTimeCalculator.summary(sessions: sessions, from: start, until: now)
        guard summary.sessionCount == 2, summary.totalSeconds == 600 else {
            throw CheckFailure(description: "screen-time summary did not clip sessions to its requested window")
        }
        guard ScreenTimeCalculator.shouldPromptBreak(
            sessionStartedAt: start,
            now: Date(timeIntervalSince1970: 2_600),
            intervalMinutes: 25,
            isPaused: false
        ) else {
            throw CheckFailure(description: "break reminder did not trigger after the configured interval")
        }
    },
    CheckCase(name: "desktopCleanupPreviewExcludesUnsafeEntries") {
        struct FixtureFileSystem: DesktopFileSystem {
            let root: URL
            let files: [URL: (directory: Bool, symlink: Bool, size: Int64)]
            func contentsOfDirectory(at url: URL) throws -> [URL] { Array(files.keys) }
            func byteCount(for url: URL) throws -> Int64 { files[url]?.size ?? 0 }
            func isDirectory(_ url: URL) throws -> Bool { files[url]?.directory ?? false }
            func isSymbolicLink(_ url: URL) throws -> Bool { files[url]?.symlink ?? false }
            func moveToTrash(_ url: URL) throws {}
        }
        let desktop = URL(fileURLWithPath: "/tmp/pounce-desktop")
        let safe = desktop.appendingPathComponent("notes.txt")
        let hidden = desktop.appendingPathComponent(".secret")
        let folder = desktop.appendingPathComponent("Folder")
        let link = desktop.appendingPathComponent("link.txt")
        let fileSystem = FixtureFileSystem(
            root: desktop,
            files: [safe: (false, false, 12), hidden: (false, false, 2), folder: (true, false, 0), link: (false, true, 1)]
        )
        guard case let .success(candidates) = DesktopCleanupService(fileSystem: fileSystem).preview(desktopURL: desktop) else {
            throw CheckFailure(description: "cleanup preview failed to enumerate fixture")
        }
        guard candidates.map(\.name) == ["notes.txt"] else {
            throw CheckFailure(description: "cleanup preview returned " + candidates.map(\.name).joined(separator: ","))
        }
    },
    CheckCase(name: "roamingPathInterpolatesAndClampsProgress") {
        let start = CGPoint(x: 10, y: 20)
        let end = CGPoint(x: 110, y: 220)
        guard PounceMotionPath.point(from: start, to: end, progress: 0.5) == CGPoint(x: 60, y: 120),
              PounceMotionPath.point(from: start, to: end, progress: -1) == start,
              PounceMotionPath.point(from: start, to: end, progress: 2) == end else {
            throw CheckFailure(description: "roaming path did not interpolate or clamp progress")
        }
    },
    CheckCase(name: "roamStrollStaysNearbyAndClamped") {
        let origin = CGPoint(x: 400, y: 400)
        let frame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let size = CGSize(width: 180, height: 180)
        guard let plan = CatRoam.plan(
            from: origin,
            windowSize: size,
            visibleFrame: frame,
            gait: .stroll,
            angle: 0,
            distanceUnit: 1
        ) else {
            throw CheckFailure(description: "stroll roam produced no plan")
        }
        let distance = hypot(plan.destination.x - origin.x, plan.destination.y - origin.y)
        let maxX = frame.maxX - size.width
        guard plan.gait == .stroll,
              plan.activity == .walking,
              distance >= 90, distance <= 240,
              plan.destination.x <= maxX,
              plan.destination.y >= frame.minY,
              plan.destination.y <= frame.maxY - size.height else {
            throw CheckFailure(description: "stroll did not stay nearby or inside the visible frame")
        }
    },
    CheckCase(name: "roamZoomTravelsFartherThanStroll") {
        let origin = CGPoint(x: 200, y: 200)
        let frame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let size = CGSize(width: 180, height: 180)
        guard let stroll = CatRoam.plan(
            from: origin, windowSize: size, visibleFrame: frame,
            gait: .stroll, angle: 0.35, distanceUnit: 1
        ), let zoom = CatRoam.plan(
            from: origin, windowSize: size, visibleFrame: frame,
            gait: .zoom, angle: 0.35, distanceUnit: 1
        ) else {
            throw CheckFailure(description: "expected both stroll and zoom plans")
        }
        let strollDistance = hypot(stroll.destination.x - origin.x, stroll.destination.y - origin.y)
        let zoomDistance = hypot(zoom.destination.x - origin.x, zoom.destination.y - origin.y)
        guard zoom.activity == .zooming, zoomDistance > strollDistance * 1.4 else {
            throw CheckFailure(description: "zoom gait did not cover more ground than a stroll")
        }
    },
    CheckCase(name: "roamDurationMatchesGaitAndDistance") {
        let shortStroll = CatRoam.duration(distance: 100, gait: .stroll)
        let longStroll = CatRoam.duration(distance: 220, gait: .stroll)
        let zoom = CatRoam.duration(distance: 220, gait: .zoom)
        let pounce = CatRoam.duration(distance: 80, gait: .pounce)
        guard longStroll > shortStroll,
              zoom < longStroll,
              pounce < 0.8,
              shortStroll >= 0.55, longStroll <= 2.4 else {
            throw CheckFailure(description: "roam duration did not scale with distance or gait")
        }
    },
    CheckCase(name: "roamEaseStartsAndStopsSlowly") {
        guard PounceMotionPath.easedProgress(0) == 0,
              PounceMotionPath.easedProgress(1) == 1,
              abs(PounceMotionPath.easedProgress(0.5) - 0.5) < 0.001,
              PounceMotionPath.easedProgress(0.25) < 0.25,
              PounceMotionPath.easedProgress(0.75) > 0.75 else {
            throw CheckFailure(description: "roam easing was not slow-in and slow-out")
        }
    },
    CheckCase(name: "roamHopPeaksMidTravel") {
        let mid = PounceMotionPath.hopOffset(progress: 0.5, height: 24)
        let start = PounceMotionPath.hopOffset(progress: 0, height: 24)
        let end = PounceMotionPath.hopOffset(progress: 1, height: 24)
        guard start == 0, end == 0, abs(mid - 24) < 0.001 else {
            throw CheckFailure(description: "pounce hop did not peak at mid-travel")
        }
    },
    CheckCase(name: "roamRestAndOffscreenMovesProduceNoPlan") {
        let origin = CGPoint(x: 0, y: 0)
        let frame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let size = CGSize(width: 180, height: 180)
        let rest = CatRoam.plan(
            from: origin, windowSize: size, visibleFrame: frame,
            gait: .rest, angle: 0, distanceUnit: 1
        )
        let offscreen = CatRoam.plan(
            from: origin, windowSize: size, visibleFrame: frame,
            gait: .stroll, angle: .pi, distanceUnit: 1
        )
        guard rest == nil, offscreen == nil else {
            throw CheckFailure(description: "rest or fully clamped roam still produced a destination")
        }
    },
    CheckCase(name: "playfulKittenRoamsMoreThanSleepyLoaf") {
        let units = stride(from: 0.0, to: 1.0, by: 0.01).map { $0 }
        let kittenRest = units.filter { CatRoam.pickGait(unit: $0, personality: .playfulKitten) == .rest }.count
        let loafRest = units.filter { CatRoam.pickGait(unit: $0, personality: .sleepyLoaf) == .rest }.count
        let kittenZoom = units.filter { CatRoam.pickGait(unit: $0, personality: .playfulKitten) == .zoom }.count
        guard kittenRest < loafRest, kittenZoom > 10 else {
            throw CheckFailure(description: "playful kitten did not roam more than sleepy loaf")
        }
    },
    CheckCase(name: "attentionLevelsUseShorterRoamIntervals") {
        guard AppCoordinator.roamInterval(for: .calm) == 8...14,
              AppCoordinator.roamInterval(for: .balanced) == 4...8,
              AppCoordinator.roamInterval(for: .lively) == 2...5 else {
            throw CheckFailure(description: "roam intervals were not shorter, attention-scaled waits")
        }
    },
    CheckCase(name: "locomotionActivitiesLoopWhileStationaryDoNot") {
        guard CatAnimationTiming.loops(for: .walking),
              CatAnimationTiming.loops(for: .zooming),
              CatAnimationTiming.loops(for: .pouncing),
              CatAnimationTiming.loops(for: .kneading),
              !CatAnimationTiming.loops(for: .sitting),
              !CatAnimationTiming.loops(for: .sleeping) else {
            throw CheckFailure(description: "walk and zoom poses did not loop, or idle poses looped")
        }
    },
    CheckCase(name: "viewModelLocomotionFacesTravelDirection") {
        let defaults = UserDefaults(suiteName: "PounceChecks-\(UUID().uuidString)")!
        let model = CatViewModel(store: PetStateStore(defaults: defaults))
        model.setLocomotion(.zooming, facing: -1)
        guard model.activity == .zooming, model.facing == -1 else {
            throw CheckFailure(description: "locomotion did not face the travel direction")
        }
        model.setLocomotion(nil)
        guard model.activity == .sitting, model.facing == -1 else {
            throw CheckFailure(description: "ending locomotion did not settle while keeping facing")
        }
    }
]

private func wavPCM(_ data: Data) throws -> (sampleRate: Int, samples: [Int16]) {
    guard data.count > 44,
          String(data: data.prefix(4), encoding: .ascii) == "RIFF" else {
        throw CheckFailure(description: "procedural cat voice was not a WAV")
    }
    let sampleRate = Int(
        UInt32(data[24])
            | UInt32(data[25]) << 8
            | UInt32(data[26]) << 16
            | UInt32(data[27]) << 24
    )
    var samples: [Int16] = []
    samples.reserveCapacity((data.count - 44) / 2)
    var offset = 44
    while offset + 1 < data.count {
        let value = Int16(bitPattern: UInt16(data[offset]) | UInt16(data[offset + 1]) << 8)
        samples.append(value)
        offset += 2
    }
    return (sampleRate, samples)
}

private func zeroCrossingRatesByThird(_ samples: [Int16]) -> [Double] {
    let third = max(1, samples.count / 3)
    return (0..<3).map { index in
        let start = index * third
        let end = index == 2 ? samples.count : start + third
        return zeroCrossingRate(samples[start..<end])
    }
}

private func zeroCrossingRate(_ samples: ArraySlice<Int16>) -> Double {
    guard samples.count > 1 else { return 0 }
    var crossings = 0
    var previous = samples[samples.startIndex]
    for value in samples.dropFirst() {
        if (previous < 0 && value >= 0) || (previous >= 0 && value < 0) {
            crossings += 1
        }
        previous = value
    }
    return Double(crossings) / Double(samples.count - 1)
}

private func pulseCount(_ samples: [Int16], sampleRate: Int) -> Int {
    let window = max(1, sampleRate / 80)
    var energies: [Double] = []
    var index = 0
    while index < samples.count {
        let end = min(index + window, samples.count)
        var sum = 0.0
        for sample in samples[index..<end] {
            let x = Double(sample) / 32_768
            sum += x * x
        }
        energies.append(sum / Double(end - index))
        index += window
    }
    let threshold = (energies.max() ?? 0) * 0.35
    guard energies.count >= 3 else { return 0 }
    var count = 0
    for i in 1..<(energies.count - 1) where
        energies[i] > energies[i - 1]
        && energies[i] >= energies[i + 1]
        && energies[i] >= threshold
    {
        count += 1
    }
    return count
}

@MainActor
private func selectedChecks(arguments: [String]) throws -> [CheckCase] {
    guard !arguments.isEmpty else { return checks }
    guard arguments.count == 2, arguments[0] == "--filter" else {
        throw CheckFailure(description: "usage: PounceChecks [--filter <substring>]")
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
