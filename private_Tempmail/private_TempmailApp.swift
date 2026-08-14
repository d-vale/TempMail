import AppKit
import CoreServices
import ServiceManagement
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
        // Lancée par macOS à l'ouverture de session, l'app démarre sans fenêtre.
        .defaultLaunchBehavior(AppDelegate.launchedInBackground ? .suppressed : .presented)
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

    /// Vrai quand c'est macOS qui a lancé l'app à l'ouverture de session : ni
    /// fenêtre ni icône dans le Dock, comme si la fenêtre venait d'être fermée.
    private(set) static var launchedInBackground = false

    private static let didRegisterLoginItemKey = "didRegisterLoginItem"

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Le drapeau « lancé comme élément d'ouverture » voyage dans l'Apple
        // Event de lancement, lisible seulement pendant son traitement.
        if Self.isLoginItemAppleEvent() || CommandLine.arguments.contains("--background") {
            startInBackground()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Filet : certains lancements par launchd n'exposent pas le drapeau
        // Apple Event. `launchIsDefault` vaut aussi `false` pour une simple
        // restauration d'état, d'où la condition sur l'élément d'ouverture.
        let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        if !isDefaultLaunch, SMAppService.mainApp.status == .enabled {
            startInBackground()
        }

        registerLoginItemOnFirstRun()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // La fenêtre est encore listée pendant la notification : attendre
            // le tour de boucle suivant pour compter ce qui reste.
            DispatchQueue.main.async { self?.updateDockVisibility() }
        }

        if Self.launchedInBackground { closeUserWindows() }
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

    // MARK: - Démarrage en tâche de fond

    private func startInBackground() {
        guard !Self.launchedInBackground else { return }
        Self.launchedInBackground = true
        NSApp.setActivationPolicy(.accessory)
    }

    private static func isLoginItemAppleEvent() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// Referme la fenêtre si SwiftUI l'a créée malgré `.suppressed` : selon le
    /// moment où la scène est évaluée, le drapeau peut ne pas être encore posé.
    private func closeUserWindows(remainingAttempts: Int = 10) {
        NSApp.windows.filter(Self.isUserWindow).forEach { $0.close() }

        guard remainingAttempts > 0 else {
            // SwiftUI a pu repasser l'app en `.regular` en installant ses
            // scènes : verrouiller la politique sur ce qui reste affiché.
            updateDockVisibility()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.closeUserWindows(remainingAttempts: remainingAttempts - 1)
        }
    }

    // MARK: - Élément d'ouverture

    /// Inscrit l'app aux éléments d'ouverture au tout premier lancement. Le
    /// drapeau est posé avant la tentative : décochée ensuite, la case reste
    /// décochée.
    private func registerLoginItemOnFirstRun() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didRegisterLoginItemKey) else { return }
        defaults.set(true, forKey: Self.didRegisterLoginItemKey)
        guard SMAppService.mainApp.status == .notRegistered else { return }
        try? SMAppService.mainApp.register()
    }

    // MARK: - Dock

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
