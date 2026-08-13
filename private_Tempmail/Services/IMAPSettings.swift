import Foundation

/// Réglages IMAP : host/port/identifiant dans UserDefaults, mot de passe dans le Trousseau.
struct IMAPSettings {
    private static let defaults = UserDefaults.standard

    var host: String {
        get { Self.defaults.string(forKey: "imapHost") ?? "" }
        nonmutating set { Self.defaults.set(newValue, forKey: "imapHost") }
    }

    var port: Int {
        get {
            let value = Self.defaults.integer(forKey: "imapPort")
            return value == 0 ? 993 : value
        }
        nonmutating set { Self.defaults.set(newValue, forKey: "imapPort") }
    }

    var username: String {
        get { Self.defaults.string(forKey: "imapUsername") ?? "" }
        nonmutating set { Self.defaults.set(newValue, forKey: "imapUsername") }
    }

    var password: String? {
        get { KeychainService.loadPassword(account: username) }
        nonmutating set {
            if let newValue, !newValue.isEmpty {
                KeychainService.savePassword(newValue, account: username)
            } else {
                KeychainService.deletePassword(account: username)
            }
        }
    }

    /// Domaine des adresses générées, dérivé de l'identifiant IMAP.
    /// Vide tant que l'identifiant n'est pas configuré.
    var domain: String {
        username.split(separator: "@").last.map(String.init) ?? ""
    }

    var cleanupEnabled: Bool {
        get { Self.defaults.object(forKey: "cleanupEnabled") as? Bool ?? true }
        nonmutating set { Self.defaults.set(newValue, forKey: "cleanupEnabled") }
    }

    var cleanupHours: Int {
        get {
            let value = Self.defaults.integer(forKey: "cleanupHours")
            return value == 0 ? 24 : value
        }
        nonmutating set { Self.defaults.set(newValue, forKey: "cleanupHours") }
    }

    func makeConfig() -> MailboxService.Config? {
        guard !host.isEmpty, !username.isEmpty,
              let password, !password.isEmpty else { return nil }
        return MailboxService.Config(host: host, port: port, username: username, password: password)
    }
}
