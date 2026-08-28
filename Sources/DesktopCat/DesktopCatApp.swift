import AppKit
import DesktopCatCore
import SwiftUI

@MainActor
final class DesktopCatApplicationDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }
}

@main
@MainActor
struct DesktopCatApp: App {
    @NSApplicationDelegateAdaptor(DesktopCatApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        MenuBarExtra("Desktop Cat", systemImage: "cat.fill") {
            MenuBarContent(controller: applicationDelegate.coordinator.menuController)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: applicationDelegate.coordinator.menuController)
        }
    }
}
