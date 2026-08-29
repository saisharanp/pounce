import AppKit
import PounceCore
import SwiftUI

@MainActor
final class PounceApplicationDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }
}

@main
@MainActor
struct PounceApp: App {
    @NSApplicationDelegateAdaptor(PounceApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        MenuBarExtra("Pounce", systemImage: "cat.fill") {
            MenuBarContent(controller: applicationDelegate.coordinator.menuController)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: applicationDelegate.coordinator.menuController)
        }
    }
}
