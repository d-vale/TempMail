import SwiftUI

/// Vue racine, utilisée à la fois dans la fenêtre principale et dans le
/// popover de la barre de menus.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    /// Affichée dans le popover de la barre de menus (ajoute le bouton
    /// d'ouverture de la fenêtre principale) plutôt que dans la fenêtre.
    var isPopover = false

    /// Clé de navigation du groupe « Autres » (mails hors adresses suivies).
    static let othersKey = "__autres__"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                addressList
                Divider()
                footer
            }
            .navigationDestination(for: String.self) { address in
                MailListView(address: address)
            }
            .navigationDestination(for: MailSummary.self) { summary in
                MailDetailView(summary: summary)
            }
        }
        .frame(minWidth: 340, minHeight: 420)
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    model.createAddress()
                } label: {
                    Label("Nouvelle adresse", systemImage: "plus.circle.fill")
                }
                .controlSize(.large)
                .disabled(model.settings.domain.isEmpty)
                Spacer()
                Button {
                    model.refreshNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Actualiser maintenant")
            }
            HStack(spacing: 6) {
                statusDot
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let copied = model.lastCopiedAddress {
                    Text("Copiée : \(copied)")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(10)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch model.connectionState {
        case .ok: .green
        case .idle: .gray
        case .offline: .orange
        case .authFailed, .missingPassword: .red
        }
    }

    private var statusText: String {
        switch model.connectionState {
        case .ok:
            if let date = model.lastRefresh {
                return "Connecté — actualisé à \(date.formatted(date: .omitted, time: .shortened))"
            }
            return "Connecté"
        case .idle:
            return "Connexion…"
        case .offline:
            return "Hors ligne — nouvel essai dans 30 s"
        case .authFailed:
            return "Échec d'authentification — vérifiez les Réglages"
        case .missingPassword:
            return "Compte non configuré — ouvrez les Réglages"
        }
    }

    private var addressList: some View {
        List {
            if model.addresses.isEmpty && model.otherMails.isEmpty {
                Text("Cliquez sur « Nouvelle adresse » pour créer une adresse jetable ; elle sera copiée dans le presse-papier.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
            ForEach(model.addresses) { temp in
                NavigationLink(value: temp.address) {
                    addressRow(temp)
                }
                .contextMenu {
                    Button("Copier l'adresse") { model.copyToClipboard(temp.address) }
                    Button("Supprimer de la liste", role: .destructive) { model.removeAddress(temp) }
                }
            }
            if !model.otherMails.isEmpty {
                NavigationLink(value: Self.othersKey) {
                    HStack {
                        Label("Autres destinataires", systemImage: "tray")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(model.otherMails.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func addressRow(_ temp: TempAddress) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(temp.address)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(model.mails(for: temp.address).count) mail(s) — créée \(temp.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let unread = model.unreadCounts[temp.address], unread > 0 {
                Text("\(unread)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.red))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if isPopover {
                Button {
                    openMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                }
                .help("Ouvrir la fenêtre")
            }
            SettingsLink {
                Label("Réglages…", systemImage: "gearshape")
            }
            Spacer()
            Button("Quitter") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
    }

    /// Rétablit l'icône du Dock avant d'ouvrir la fenêtre : une app passée en
    /// mode accessoire n'obtiendrait pas le premier plan.
    private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: AppDelegate.mainWindowID)
        WindowRaiser.raise(identifiedBy: AppDelegate.mainWindowID)
    }
}

/// Remonte une fenêtre devant celles des autres applications. Cliquer un
/// élément de la barre de menus n'active pas l'app : sans cela, la fenêtre
/// ouverte depuis le popover apparaît derrière tout le reste.
enum WindowRaiser {

    static func raise(identifiedBy fragment: String, remainingAttempts: Int = 10) {
        NSApp.activate()

        guard let window = NSApp.windows.first(where: { matches($0, fragment) }) else {
            // La fenêtre n'est créée qu'un ou plusieurs tours de boucle plus
            // tard, et le passage en mode `regular` n'est pas immédiat.
            guard remainingAttempts > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                raise(identifiedBy: fragment, remainingAttempts: remainingAttempts - 1)
            }
            return
        }

        window.collectionBehavior.insert(.moveToActiveSpace)
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        // Niveau normal une fois devant, pour ne pas rester au-dessus de tout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.activate()
            window.level = .normal
        }
    }

    /// SwiftUI ne renseigne pas toujours `identifier` ; le nom de sauvegarde de
    /// position, lui, reprend l'identifiant de scène (« main »,
    /// « com_apple_SwiftUI_Settings_window »).
    private static func matches(_ window: NSWindow, _ fragment: String) -> Bool {
        window.identifier?.rawValue.localizedCaseInsensitiveContains(fragment) == true
            || window.frameAutosaveName.localizedCaseInsensitiveContains(fragment)
    }
}
