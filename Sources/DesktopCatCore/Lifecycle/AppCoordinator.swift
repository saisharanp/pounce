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
    public private(set) var windowController: DesktopCatWindowController?
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
            }
        )
    }()

    private var idleTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?
    private var hotKeyController: DesktopCatHotKeyController?

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

        let windowController = DesktopCatWindowController(
            state: viewModel.state,
            workspaceObserver: workspaceObserver,
            viewModel: viewModel,
            menuController: menuController
        )
        self.windowController = windowController
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
        hotKeyController = DesktopCatHotKeyController(menuController: menuController)

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
