import Foundation
import SwiftMail

@main
struct TempMailProbe {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("Erreur: \(error)\n", stderr)
            exit(1)
        }
    }

    static func run() async throws {
        guard let host = ProcessInfo.processInfo.environment["IMAP_HOST"],
              let user = ProcessInfo.processInfo.environment["IMAP_USER"] else {
            fputs("Variables d'environnement requises : IMAP_HOST, IMAP_USER (et IMAP_PASSWORD, sinon demandé).\n", stderr)
            fputs("Exemple : IMAP_HOST=imap.example.com IMAP_USER=catchall@example.com swift run\n", stderr)
            exit(1)
        }
        let password = ProcessInfo.processInfo.environment["IMAP_PASSWORD"]
            ?? String(cString: getpass("Mot de passe IMAP pour \(user): "))

        guard !password.isEmpty else {
            fputs("Mot de passe vide — abandon.\n", stderr)
            exit(1)
        }

        print("Connexion à \(host):993 (TLS)…")
        let server = IMAPServer(host: host, port: 993)
        try await server.connect()
        try await server.login(username: user, password: password)

        let selection = try await server.selectMailbox("INBOX")
        print("INBOX sélectionnée : \(selection.messageCount) message(s)")

        guard selection.messageCount > 0, let latest = selection.latest(5) else {
            print("Boîte vide — envoyez un mail à une adresse quelconque de votre domaine catch-all puis relancez.")
            try await server.disconnect()
            return
        }

        let infos = try await server.fetchMessageInfosBulk(
            using: latest,
            options: [.envelope, .internalDate, .flags],
            headerFields: ["Delivered-To", "X-Original-To", "Envelope-To", "X-Envelope-To"]
        )

        let sorted = infos.sorted {
            ($0.internalDate ?? .distantPast) > ($1.internalDate ?? .distantPast)
        }

        print("\n=== \(sorted.count) dernier(s) mail(s) ===")
        for info in sorted {
            print(String(repeating: "-", count: 60))
            print("Sujet   : \(info.subject ?? "(sans sujet)")")
            print("De      : \(info.from ?? "?")")
            print("Date    : \(info.internalDate.map { "\($0)" } ?? "?")")
            print("To (envelope) : \(info.to)")
            if !info.cc.isEmpty {
                print("Cc (envelope) : \(info.cc)")
            }
            if let fields = info.additionalFields, !fields.isEmpty {
                print("En-têtes bruts :")
                for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
                    print("  \(name): \(value)")
                }
            } else {
                print("En-têtes bruts : (aucun des en-têtes demandés n'est présent)")
            }
        }
        print(String(repeating: "-", count: 60))
        print("""

        → Vérifiez quel en-tête contient l'adresse réellement visée
          (attendu : X-Original-To ou Delivered-To ≠ l'adresse catch-all,
           sinon le To d'enveloppe).
        """)

        try await server.disconnect()
    }
}
