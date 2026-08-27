import AppKit
import SwiftUI

/// Owns the companion's transparent, non-activating desktop panel. Task 6
/// replaces its empty SwiftUI host with the cat renderer.
@MainActor
public final class DesktopCatWindowController: NSWindowController {
    private let workspaceObserver: WorkspaceObserver
    private var screenParametersObserver: NSObjectProtocol?
    private var requestedVisibility = true
    private var isFullscreenActive = false
    private var hidesInFullscreen = true

    public init(
        state: PetState,
        windowSize: CGSize = CGSize(width: 180, height: 180),
        workspaceObserver: WorkspaceObserver = WorkspaceObserver(),
        viewModel: CatViewModel? = nil,
        menuController: MenuBarController? = nil
    ) {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let resolvedViewModel = viewModel ?? CatViewModel(
            store: PetStateStore(),
            initialState: state
        )
        let resolvedMenuController = menuController ?? MenuBarController(
            viewModel: resolvedViewModel
        )
        panel.contentView = CatHostingView(
            rootView: CatView(
                viewModel: resolvedViewModel,
                controller: resolvedMenuController
            ),
            viewModel: resolvedViewModel
        )

        self.workspaceObserver = workspaceObserver
        super.init(window: panel)
        resolvedMenuController.connect(windowController: self)

        hidesInFullscreen = state.hideInFullscreen
        isFullscreenActive = workspaceObserver.isFullscreenAppActive
        setWindowLevel(state.windowLevel)
        setClickThrough(state.clickThrough)
        moveToRelativeOrigin(state.windowOrigin)
        workspaceObserver.onFullscreenStateChanged = { [weak self] isFullscreen in
            self?.setFullscreenActive(isFullscreen)
        }
        applyVisibility()

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.clampToCurrentScreen()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("DesktopCatWindowController does not support coder initialization")
    }

    deinit {
        MainActor.assumeIsolated {
            if let screenParametersObserver {
                NotificationCenter.default.removeObserver(screenParametersObserver)
            }
        }
    }

    public func setClickThrough(_ enabled: Bool) {
        window?.ignoresMouseEvents = enabled
    }

    public func setVisible(_ visible: Bool) {
        requestedVisibility = visible
        applyVisibility()
    }

    public func setHideInFullscreen(_ enabled: Bool) {
        hidesInFullscreen = enabled
        applyVisibility()
    }

    public func setWindowLevel(_ level: PetWindowLevel) {
        window?.level = level == .desktop
            ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            : .floating
    }

    public func moveToVisibleFrame(_ visibleFrame: CGRect) {
        guard let window else { return }
        window.setFrameOrigin(
            Self.clampedOrigin(
                window.frame.origin,
                windowSize: window.frame.size,
                visibleFrame: visibleFrame
            )
        )
    }

    public static func clampedOrigin(
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

    public static func shouldShow(
        requestedVisibility: Bool,
        isFullscreenActive: Bool,
        hideInFullscreen: Bool
    ) -> Bool {
        requestedVisibility && !(hideInFullscreen && isFullscreenActive)
    }

    private func moveToRelativeOrigin(_ relativeOrigin: ScreenRelativePoint) {
        guard let visibleFrame = NSScreen.main?.visibleFrame,
              let window else { return }
        let origin = CGPoint(
            x: visibleFrame.minX + CGFloat(relativeOrigin.x) * max(0, visibleFrame.width - window.frame.width),
            y: visibleFrame.minY + CGFloat(relativeOrigin.y) * max(0, visibleFrame.height - window.frame.height)
        )
        window.setFrameOrigin(
            Self.clampedOrigin(origin, windowSize: window.frame.size, visibleFrame: visibleFrame)
        )
    }

    private func clampToCurrentScreen() {
        guard let window else { return }
        let screen = NSScreen.screens.first { $0.frame.intersects(window.frame) } ?? NSScreen.main
        guard let screen else { return }
        moveToVisibleFrame(screen.visibleFrame)
    }

    private func setFullscreenActive(_ active: Bool) {
        isFullscreenActive = active
        applyVisibility()
    }

    private func applyVisibility() {
        if Self.shouldShow(
            requestedVisibility: requestedVisibility,
            isFullscreenActive: isFullscreenActive,
            hideInFullscreen: hidesInFullscreen
        ) {
            window?.orderFront(nil)
        } else {
            window?.orderOut(nil)
        }
    }
}

@MainActor
private final class CatHostingView: NSHostingView<CatView> {
    private let viewModel: CatViewModel

    init(rootView: CatView, viewModel: CatViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: CatView) {
        fatalError("Use init(rootView:viewModel:)")
    }

    required init?(coder: NSCoder) {
        fatalError("CatHostingView does not support coder initialization")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let scale = min(max(viewModel.state.catScale, 0.65), 1.3)
        let illustratedSide = 132 * scale
        let illustratedBounds = CGRect(
            x: bounds.midX - illustratedSide / 2,
            y: bounds.midY - illustratedSide / 2,
            width: illustratedSide,
            height: illustratedSide
        )
        guard CatHitArea.contains(point, in: illustratedBounds) else {
            return nil
        }
        return super.hitTest(point)
    }
}
