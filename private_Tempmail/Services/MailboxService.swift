import Foundation
import SwiftMail

/// Accès IMAP à la boîte catch-all. Connexion persistante à reconnexion
/// paresseuse : la session est gardée entre les polls ; toute erreur
/// l'invalide et l'opération suivante reconnecte.
actor MailboxService {

    struct Config: Sendable, Equatable {
        var host: String
        var port: Int
        var username: String
        var password: String
    }

    struct MailboxSnapshot: Sendable {
        let uidValidity: UInt32
        let messageCount: Int
        let infos: [MessageInfo]
    }

    /// En-têtes consultés pour retrouver le destinataire réel (voir RecipientExtractor).
    static let recipientHeaderFields = ["Delivered-To", "X-Original-To", "Envelope-To", "X-Envelope-To"]

    /// Options légères pour les listings — jamais `.default` (BODYSTRUCTURE trop lourd en masse).
    private static let listOptions: FetchMessageInfoOptions = [.envelope, .internalDate, .flags]

    private var server: IMAPServer?
    private var activeConfig: Config?

    // MARK: - Session

    private func session(_ config: Config) async throws -> IMAPServer {
        if let server, activeConfig == config {
            return server
        }
        await invalidate()
        let fresh = IMAPServer(host: config.host, port: config.port)
        do {
            try await fresh.connect()
            try await fresh.login(username: config.username, password: config.password)
        } catch {
            try? await fresh.disconnect()
            throw error
        }
        server = fresh
        activeConfig = config
        return fresh
    }

    private func invalidate() async {
        if let server {
            try? await server.disconnect()
        }
        server = nil
        activeConfig = nil
    }

    private func perform<T: Sendable>(_ config: Config,
                                      _ work: (IMAPServer) async throws -> T) async throws -> T {
        do {
            return try await work(try await session(config))
        } catch {
            await invalidate()
            throw error
        }
    }

    // MARK: - Opérations

    /// Charge les `limit` derniers mails (baseline / rafraîchissement complet).
    func fetchRecent(config: Config, limit: Int = 200) async throws -> MailboxSnapshot {
        try await perform(config) { server in
            let selection = try await server.selectMailbox("INBOX")
            var infos: [MessageInfo] = []
            if selection.messageCount > 0, let latest = selection.latest(limit) {
                infos = try await server.fetchMessageInfosBulk(
                    using: latest,
                    options: Self.listOptions,
                    headerFields: Self.recipientHeaderFields
                )
            }
            return MailboxSnapshot(uidValidity: selection.uidValidity.value,
                                   messageCount: selection.messageCount,
                                   infos: infos)
        }
    }

    /// Poll incrémental : un seul `UID FETCH n:*`.
    func fetchNew(config: Config, sinceUID: UInt32) async throws -> MailboxSnapshot {
        try await perform(config) { server in
            let selection = try await server.selectMailbox("INBOX")
            var infos: [MessageInfo] = []
            if selection.messageCount > 0 {
                infos = try await server.fetchMessageInfos(
                    uidRange: UID(sinceUID + 1)...,
                    options: Self.listOptions,
                    headerFields: Self.recipientHeaderFields
                )
                // `n:*` renvoie toujours le dernier message, même si son UID <= n.
                infos = infos.filter { ($0.uid?.value ?? 0) > sinceUID }
            }
            return MailboxSnapshot(uidValidity: selection.uidValidity.value,
                                   messageCount: selection.messageCount,
                                   infos: infos)
        }
    }

    /// Corps complet d'un mail (décodage MIME par SwiftMail).
    func fetchContent(config: Config, of info: MessageInfo) async throws -> MailContent {
        try await perform(config) { server in
            let message = try await server.fetchMessage(from: info)
            return MailContent(html: message.htmlBody,
                               text: message.textBody,
                               attachmentCount: message.attachments.count)
        }
    }

    /// Supprime côté serveur (STORE \Deleted + EXPUNGE) tout mail plus vieux que `cutoff`.
    /// Filtrage INTERNALDATE côté client : IMAP `BEFORE` n'a qu'une granularité jour.
    func deleteMessages(config: Config, olderThan cutoff: Date) async throws -> Int {
        try await perform(config) { server in
            let selection = try await server.selectMailbox("INBOX")
            guard selection.messageCount > 0 else { return 0 }

            let infos = try await server.fetchMessageInfosBulk(
                using: SequenceNumberSet(1...selection.messageCount),
                options: [.internalDate]
            )
            let uids = infos.compactMap { info -> UID? in
                guard let date = info.internalDate, date < cutoff else { return nil }
                return info.uid
            }
            guard !uids.isEmpty else { return 0 }

            let set = UIDSet(uids)
            try await server.store(flags: [.deleted], on: set, operation: .add)
            if await server.supportsUIDPlus {
                try await server.expunge(messages: set)
            } else {
                try await server.expunge()
            }
            return uids.count
        }
    }

    /// Test de connexion depuis les Réglages : session neuve à chaque appel.
    func verify(config: Config) async throws {
        await invalidate()
        _ = try await perform(config) { server in
            try await server.selectMailbox("INBOX")
        }
    }
}
