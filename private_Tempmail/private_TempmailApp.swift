import AppKit
import SwiftUI

@main
struct private_TempmailApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Fenêtre principale : l'app se lance comme n'importe quelle app, avec
        // son icône dans le Dock. La fermer retire l'icône du Dock, l'app
        // continuant de tourner dans la barre de menus (cf. AppDelegate).
        Window("Private Mailtemp", id: AppDelegate.mainWindowID) {
            RootView()
                .environment(model)
                .frame(minWidth: 380, minHeight: 500)
        }
        .defaultSize(width: 420, height: 560)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            RootView(isPopover: true)
                .environment(model)
                .frame(width: 360, height: 460)
        } label: {
            Image(systemName: "tray.full")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

/// Gère la présence dans le Dock : visible tant qu'une fenêtre est ouverte,
/// masquée sinon — l'app reste alors accessible par la barre de menus.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let mainWindowID = "main"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // La fenêtre est encore listée pendant la notification : attendre
            // le tour de boucle suivant pour compter ce qui reste.
            DispatchQueue.main.async { self?.updateDockVisibility() }
        }
    }

    /// Rouvre la fenêtre au clic sur l'icône du Dock (quand elle est visible).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.activate()
            NSApp.windows.first { $0.identifier?.rawValue.contains(Self.mainWindowID) == true }?
                .makeKeyAndOrderFront(nil)
        }
        return true
    }

    /// Fermer la dernière fenêtre ne quitte pas l'app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func updateDockVisibility() {
        let hasWindow = NSApp.windows.contains(where: Self.isUserWindow)
        NSApp.setActivationPolicy(hasWindow ? .regular : .accessory)
    }

    /// Fenêtre « réelle » (principale ou Réglages), par opposition au popover
    /// de la barre de menus et aux fenêtres techniques.
    private static func isUserWindow(_ window: NSWindow) -> Bool {
        window.isVisible && window.level == .normal && window.canBecomeMain && !(window is NSPanel)
    }
}
