import ServiceManagement
import SwiftUI

/// Réglages : identifiants IMAP (mot de passe → Trousseau), nettoyage auto, démarrage.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var host = ""
    @State private var portText = "993"
    @State private var username = ""
    @State private var password = ""
    @State private var loaded = false

    @State private var testing = false
    @State private var testMessage: String?
    @State private var testSucceeded: Bool?

    @State private var cleanupEnabled = true
    @State private var cleanupHours = 24

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Connexion IMAP") {
                TextField("Serveur", text: $host, prompt: Text("imap.example.com"))
                TextField("Port", text: $portText, prompt: Text("993"))
                TextField("Identifiant", text: $username, prompt: Text("catchall@example.com"))
                SecureField("Mot de passe", text: $password)
                    .textContentType(.password)

                HStack {
                    Button("Tester la connexion") { runTest() }
                        .disabled(testing || username.isEmpty || password.isEmpty)
                    if testing { ProgressView().controlSize(.small) }
                    if let testMessage {
                        Text(testMessage)
                            .font(.caption)
                            .foregroundStyle(testSucceeded == true ? .green : .red)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Enregistrer") { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }

            Section("Nettoyage automatique") {
                Toggle("Supprimer du serveur les mails anciens", isOn: $cleanupEnabled)
                    .onChange(of: cleanupEnabled) {
                        model.settings.cleanupEnabled = cleanupEnabled
                    }
                Stepper("Supprimer après \(cleanupHours) heure(s)", value: $cleanupHours, in: 1...168)
                    .disabled(!cleanupEnabled)
                    .onChange(of: cleanupHours) {
                        model.settings.cleanupHours = cleanupHours
                    }
                Text("Vérification une fois par heure. Concerne toute la boîte catch-all.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Général") {
                Toggle("Lancer au démarrage de session", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { toggleLaunchAtLogin() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            loadOnce()
            // Ouverte depuis le popover, la fenêtre n'obtient pas le focus seule.
            WindowRaiser.raise(identifiedBy: "Settings")
        }
    }

    private func loadOnce() {
        guard !loaded else { return }
        loaded = true
        let settings = model.settings
        host = settings.host
        portText = String(settings.port)
        username = settings.username
        password = settings.password ?? ""
        cleanupEnabled = settings.cleanupEnabled
        cleanupHours = settings.cleanupHours
    }

    private func save() {
        let settings = model.settings
        settings.host = host.trimmingCharacters(in: .whitespaces)
        settings.port = Int(portText) ?? 993
        // L'identifiant d'abord : le compte Trousseau du mot de passe en dépend.
        settings.username = username.trimmingCharacters(in: .whitespaces)
        settings.password = password
        testMessage = "Enregistré."
        testSucceeded = true
        model.resetAndRefresh()
    }

    private func runTest() {
        testing = true
        testMessage = nil
        let port = Int(portText) ?? 993
        let host = host.trimmingCharacters(in: .whitespaces)
        let user = username.trimmingCharacters(in: .whitespaces)
        Task {
            let result = await model.testConnection(host: host, port: port,
                                                    username: user, password: password)
            testing = false
            switch result {
            case .success:
                testMessage = "Connexion réussie ✓"
                testSucceeded = true
            case .failure(let error):
                testMessage = error.localizedDescription
                testSucceeded = false
            }
        }
    }

    private func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
