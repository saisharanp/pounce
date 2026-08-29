import AppKit
import Combine
import Foundation

/// Owns the app-wide objects that must outlive SwiftUI scene refreshes.
@MainActor
public final class AppCoordinator: ObservableObject {
    public let store: PetStateStore
    public let viewModel: CatViewModel
    public let workspaceObserver: WorkspaceObserver
    public let soundController: CatSoundController
    public private(set) var windowController: PounceWindowController?
    public private(set) var motionCoordinator: PounceMotionCoordinator?
    @Published public private(set) var requestedVisibility = true
    public private(set) var idleScheduleRevision = 0
    public private(set) var hasStarted = false

    public private(set) lazy var menuController: MenuBarController = {
        MenuBarController(
            viewModel: viewModel,
            soundController: soundController,
            isVisible: requestedVisibility,
            onSetVisibility: { [weak self] visible in
                self?.setRequestedVisibility(visible)
            },
            onSetClickThrough: { [weak self] enabled in
                self?.windowController?.setClickThrough(enabled)
            },
            onSetWindowLevel: { [weak self] level in
                self?.windowController?.setWindowLevel(level)
            },
            onSetHideInFullscreen: { [weak self] _ in
                self?.applyFullscreenPolicy()
            },
            onSetPaused: { [weak self] _ in
                self?.updateIdleWork()
            },
            onMoveWindow: { [weak self] delta in
                self?.windowController?.moveWindow(by: delta)
            },
            onDragStateChanged: { [weak self] enabled in
                self?.windowController?.setDraggingAnimation(enabled)
            },
            onSetAttentionLevel: { [weak self] _ in
                self?.updateIdleWork()
            },
            onDirectReaction: { [weak self] in
                self?.updateIdleWork()
            },
            onOpenSettings: {
                NSApplication.shared.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
            },
            reminderScheduler: SystemScreenTimeReminderScheduler()
        )
    }()

    private var idleTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?
    private var hotKeyController: PounceHotKeyController?

    public init(
        store: PetStateStore = PetStateStore(),
        workspaceObserver: WorkspaceObserver? = nil,
        soundController: CatSoundController = CatSoundController()
    ) {
        self.store = store
        viewModel = CatViewModel(store: store)
        self.workspaceObserver = workspaceObserver ?? WorkspaceObserver()
        self.soundController = soundController
    }

    deinit {
        MainActor.assumeIsolated {
            idleTask?.cancel()
            motionCoordinator?.stop()
            soundController.stop()
            if let activationObserver {
                NotificationCenter.default.removeObserver(activationObserver)
            }
            if let screenParametersObserver {
                NotificationCenter.default.removeObserver(screenParametersObserver)
            }
        }
    }

    /// Creates the panel after AppKit launches and is safe to call repeatedly.
    public func start() {
        guard !hasStarted else { return }
        hasStarted = true
        viewModel.restoreElapsedCare(now: Date())

        let windowController = PounceWindowController(
            state: viewModel.state,
            workspaceObserver: workspaceObserver,
            viewModel: viewModel,
            menuController: menuController
        )
        self.windowController = windowController
        let motionCoordinator = PounceMotionCoordinator(
            interval: { [weak self] in
                Self.roamInterval(for: self?.viewModel.state.attentionLevel ?? .balanced)
            },
            eligibility: { [weak self, weak windowController] in
                guard let self, let windowController else { return false }
                return viewModel.state.roamingEnabled
                    && !viewModel.state.reducedMotion
                    && Self.shouldScheduleIdle(
                        isVisible: windowController.isVisible,
                        isPaused: viewModel.state.isPaused,
                        isFullscreenActive: windowController.isFullscreenActive
                    )
            },
            visibleFrameProvider: { [weak windowController] in
                guard let window = windowController?.window else { return NSScreen.main?.visibleFrame }
                return window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            },
            planProvider: { [weak self] origin, frame, size in
                CatRoam.plan(
                    from: origin,
                    windowSize: size,
                    visibleFrame: frame,
                    gait: CatRoam.pickGait(
                        unit: .random(in: 0..<1),
                        personality: self?.viewModel.state.personality ?? .playfulKitten
                    ),
                    angle: .random(in: 0..<(2 * .pi)),
                    distanceUnit: .random(in: 0...1)
                )
            }
        )
        self.motionCoordinator = motionCoordinator
        motionCoordinator.start(windowController: windowController)
        windowController.onVisibilityChanged = { [weak self] _ in
            self?.updateIdleWork()
        }
        windowController.onFullscreenStateChanged = { [weak self] _ in
            self?.updateIdleWork()
        }
        windowController.onWindowOriginChanged = { [weak self] origin, displayIdentifier in
            self?.viewModel.updateState {
                $0.windowOrigin = origin
                $0.windowDisplayIdentifier = displayIdentifier
            }
        }
        hotKeyController = PounceHotKeyController(menuController: menuController)

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshLifecycleState()
            }
        }
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshLifecycleState()
            }
        }

        refreshLifecycleState()
    }

    public static func shouldScheduleIdle(
        isVisible: Bool,
        isPaused: Bool,
        isFullscreenActive: Bool
    ) -> Bool {
        isVisible && !isPaused && !isFullscreenActive
    }

    public static func idleInterval(for attentionLevel: AttentionLevel) -> ClosedRange<Int> {
        switch attentionLevel {
        case .calm: 20...35
        case .balanced: 10...20
        case .lively: 5...12
        }
    }

    public static func roamInterval(for attentionLevel: AttentionLevel) -> ClosedRange<Int> {
        switch attentionLevel {
        case .calm: 8...14
        case .balanced: 4...8
        case .lively: 2...5
        }
    }

    private func setRequestedVisibility(_ visible: Bool) {
        requestedVisibility = visible
        windowController?.setVisible(visible)
    }

    private func applyFullscreenPolicy() {
        windowController?.setHideInFullscreen(viewModel.state.hideInFullscreen)
    }

    private func refreshLifecycleState() {
        viewModel.restoreElapsedCare(now: Date())
        windowController?.refreshWorkspaceState()
        updateIdleWork()
    }

    private func updateIdleWork() {
        idleScheduleRevision &+= 1
        idleTask?.cancel()
        idleTask = nil
        guard hasStarted,
              let windowController,
              Self.shouldScheduleIdle(
                isVisible: windowController.isVisible,
                isPaused: viewModel.state.isPaused,
                isFullscreenActive: windowController.isFullscreenActive
              ) else {
            return
        }

        let interval = Self.idleInterval(for: viewModel.state.attentionLevel)
        let seconds = Int.random(in: interval)
        idleTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self,
                  Self.shouldScheduleIdle(
                    isVisible: windowController.isVisible,
                    isPaused: self.viewModel.state.isPaused,
                    isFullscreenActive: windowController.isFullscreenActive
                  ) else {
                return
            }
            self.viewModel.scheduleIdleActivity(now: Date())
            self.updateIdleWork()
        }
    }
}
