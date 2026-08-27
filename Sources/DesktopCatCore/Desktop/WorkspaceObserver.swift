import AppKit
import CoreGraphics

/// The subset of a frontmost application's window information required to
/// determine whether it covers a display. It keeps classification testable
/// without querying the window server.
public struct WorkspaceWindow: Equatable {
    public let frame: CGRect
    public let isOnScreen: Bool
    public let layer: Int

    public init(frame: CGRect, isOnScreen: Bool, layer: Int) {
        self.frame = frame
        self.isOnScreen = isOnScreen
        self.layer = layer
    }
}

/// Watches foreground-workspace changes and conservatively reports whether a
/// different application appears to occupy a full screen.
@MainActor
public final class WorkspaceObserver {
    public private(set) var isFullscreenAppActive: Bool = true {
        didSet {
            guard oldValue != isFullscreenAppActive else { return }
            onFullscreenStateChanged?(isFullscreenAppActive)
        }
    }

    public var onFullscreenStateChanged: ((Bool) -> Void)?

    private let windowDataProvider: () -> [WorkspaceWindow]?
    private let screenFrameProvider: () -> [CGRect]
    private let notificationCenter: NotificationCenter
    private var activationObserver: NSObjectProtocol?
    private var activeSpaceObserver: NSObjectProtocol?
    private var hideObserver: NSObjectProtocol?
    private var unhideObserver: NSObjectProtocol?

    public convenience init() {
        let workspace = NSWorkspace.shared
        self.init(
            windowDataProvider: { Self.frontmostWindowData(in: workspace) },
            screenFrameProvider: { NSScreen.screens.map(\.frame) },
            notificationCenter: workspace.notificationCenter,
            observedWorkspace: workspace
        )
    }

    public init(
        windowDataProvider: @escaping () -> [WorkspaceWindow]?,
        screenFrameProvider: @escaping () -> [CGRect],
        notificationCenter: NotificationCenter = .default,
        observedWorkspace: NSWorkspace? = nil
    ) {
        self.windowDataProvider = windowDataProvider
        self.screenFrameProvider = screenFrameProvider
        self.notificationCenter = notificationCenter
        activationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: observedWorkspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        activeSpaceObserver = notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: observedWorkspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        hideObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didHideApplicationNotification,
            object: observedWorkspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        unhideObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnhideApplicationNotification,
            object: observedWorkspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        refresh()
    }

    deinit {
        MainActor.assumeIsolated {
            if let activationObserver {
                notificationCenter.removeObserver(activationObserver)
            }
            if let activeSpaceObserver {
                notificationCenter.removeObserver(activeSpaceObserver)
            }
            if let hideObserver {
                notificationCenter.removeObserver(hideObserver)
            }
            if let unhideObserver {
                notificationCenter.removeObserver(unhideObserver)
            }
        }
    }

    public func refresh() {
        isFullscreenAppActive = Self.isFullscreenAppActive(
            windowData: windowDataProvider(),
            screenFrames: screenFrameProvider()
        )
    }

    /// Classifies window-server data without AppKit state. Missing window data
    /// or display data hides the cat rather than risking coverage of content.
    public static func isFullscreenAppActive(
        windowData: [WorkspaceWindow]?,
        screenFrames: [CGRect]
    ) -> Bool {
        guard let windowData, !screenFrames.isEmpty else { return true }

        return windowData.contains { window in
            window.isOnScreen && window.layer == 0 && screenFrames.contains { screen in
                framesMatchWithinTolerance(window.frame, screen)
            }
        }
    }

    /// Window-server frame values can differ from display frames by a fraction
    /// of a point; larger differences are ordinary or spanning windows.
    private static func framesMatchWithinTolerance(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let tolerance: CGFloat = 1
        return abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.size.width - rhs.size.width) <= tolerance
            && abs(lhs.size.height - rhs.size.height) <= tolerance
    }

    private static func frontmostWindowData(in workspace: NSWorkspace) -> [WorkspaceWindow]? {
        guard let frontmostProcess = workspace.frontmostApplication,
              let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else {
            return nil
        }

        let processIdentifier = frontmostProcess.processIdentifier
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        var windows: [WorkspaceWindow] = []

        for info in windowInfo {
            guard let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  ownerPID == processIdentifier,
                  ownerPID != currentProcessIdentifier else {
                continue
            }
            guard let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let isOnScreen = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else {
                return nil
            }

            windows.append(WorkspaceWindow(frame: frame, isOnScreen: isOnScreen, layer: layer))
        }

        return windows
    }
}
