import AppKit
import SwiftUI

/// A connected display used to resolve the persisted normalized window origin.
/// Its identifier is AppKit's stable display number, stored as a string so the
/// domain model remains AppKit-free and backward compatible.
public struct DesktopCatDisplay: Equatable {
    public let identifier: String
    public let visibleFrame: CGRect

    public init(identifier: String, visibleFrame: CGRect) {
        self.identifier = identifier
        self.visibleFrame = visibleFrame
    }
}

/// Owns the companion's transparent, non-activating desktop panel. Task 6
/// replaces its empty SwiftUI host with the cat renderer.
@MainActor
public final class DesktopCatWindowController: NSWindowController {
    private let workspaceObserver: WorkspaceObserver
    private var screenParametersObserver: NSObjectProtocol?
    private var windowMoveObserver: NSObjectProtocol?
    private var requestedVisibility = true
    public private(set) var isFullscreenActive = false
    public private(set) var isVisible = false
    public var onVisibilityChanged: ((Bool) -> Void)?
    public var onFullscreenStateChanged: ((Bool) -> Void)?
    public var onWindowOriginChanged: ((ScreenRelativePoint, String?) -> Void)?
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

        hidesInFullscreen = state.hideInFullscreen
        isFullscreenActive = workspaceObserver.isFullscreenAppActive
        setWindowLevel(state.windowLevel)
        setClickThrough(state.clickThrough)
        moveToRelativeOrigin(
            state.windowOrigin,
            displayIdentifier: state.windowDisplayIdentifier
        )
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
                self?.workspaceObserver.refresh()
            }
        }
        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistWindowOrigin()
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
            if let windowMoveObserver {
                NotificationCenter.default.removeObserver(windowMoveObserver)
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

    public func refreshWorkspaceState() {
        workspaceObserver.refresh()
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

    public static func restoredOrigin(
        relativeOrigin: ScreenRelativePoint,
        windowSize: CGSize,
        savedDisplayIdentifier: String?,
        displays: [DesktopCatDisplay],
        primaryDisplayIdentifier: String?
    ) -> CGPoint? {
        guard let primaryDisplay = displays.first(where: { $0.identifier == primaryDisplayIdentifier })
                ?? displays.first else {
            return nil
        }
        let display = savedDisplayIdentifier.flatMap { savedIdentifier in
            displays.first(where: { $0.identifier == savedIdentifier })
        } ?? primaryDisplay
        let visibleFrame = display.visibleFrame
        let origin = CGPoint(
            x: visibleFrame.minX + CGFloat(relativeOrigin.x) * max(0, visibleFrame.width - windowSize.width),
            y: visibleFrame.minY + CGFloat(relativeOrigin.y) * max(0, visibleFrame.height - windowSize.height)
        )
        return Self.clampedOrigin(origin, windowSize: windowSize, visibleFrame: visibleFrame)
    }

    public static func displayIdentifier(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return String(number.uint32Value)
    }

    private func moveToRelativeOrigin(
        _ relativeOrigin: ScreenRelativePoint,
        displayIdentifier: String?
    ) {
        guard let window else { return }
        let displays = NSScreen.screens.compactMap { screen -> DesktopCatDisplay? in
            guard let identifier = Self.displayIdentifier(for: screen) else { return nil }
            return DesktopCatDisplay(identifier: identifier, visibleFrame: screen.visibleFrame)
        }
        let primaryIdentifier = NSScreen.main.flatMap(Self.displayIdentifier(for:))
        guard let origin = Self.restoredOrigin(
            relativeOrigin: relativeOrigin,
            windowSize: window.frame.size,
            savedDisplayIdentifier: displayIdentifier,
            displays: displays,
            primaryDisplayIdentifier: primaryIdentifier
        ) else { return }
        window.setFrameOrigin(origin)
    }

    private func clampToCurrentScreen() {
        guard let window else { return }
        let screen = NSScreen.screens.first { $0.frame.intersects(window.frame) } ?? NSScreen.main
        guard let screen else { return }
        moveToVisibleFrame(screen.visibleFrame)
        persistWindowOrigin()
    }

    private func persistWindowOrigin() {
        guard let window,
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(window.frame) }) ?? NSScreen.main else {
            return
        }
        let visibleFrame = screen.visibleFrame
        let horizontalSpace = max(0, visibleFrame.width - window.frame.width)
        let verticalSpace = max(0, visibleFrame.height - window.frame.height)
        let origin = Self.clampedOrigin(
            window.frame.origin,
            windowSize: window.frame.size,
            visibleFrame: visibleFrame
        )
        let relativeOrigin = ScreenRelativePoint(
            x: horizontalSpace == 0 ? 0 : Double((origin.x - visibleFrame.minX) / horizontalSpace),
            y: verticalSpace == 0 ? 0 : Double((origin.y - visibleFrame.minY) / verticalSpace)
        )
        onWindowOriginChanged?(relativeOrigin, Self.displayIdentifier(for: screen))
    }

    private func setFullscreenActive(_ active: Bool) {
        isFullscreenActive = active
        applyVisibility()
        onFullscreenStateChanged?(active)
    }

    private func applyVisibility() {
        let visible = Self.shouldShow(
            requestedVisibility: requestedVisibility,
            isFullscreenActive: isFullscreenActive,
            hideInFullscreen: hidesInFullscreen
        )
        let visibilityChanged = isVisible != visible
        isVisible = visible
        if visible {
            window?.orderFront(nil)
        } else {
            window?.orderOut(nil)
        }
        if visibilityChanged {
            onVisibilityChanged?(visible)
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
