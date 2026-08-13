import AppKit
import Foundation
import Observation
import SwiftMail

/// État central de l'app : adresses suivies, mails groupés par destinataire,
/// boucle de polling IMAP (30 s) et nettoyage automatique.
@MainActor
@Observable
final class AppModel {

    enum ConnectionState: Equatable {
        case idle
        case ok
        case offline(String)
        case authFailed(String)
        case missingPassword
    }

    private(set) var addresses: [TempAddress] = []
    private(set) var mailsByAddress: [String: [MailSummary]] = [:]
    private(set) var otherMails: [MailSummary] = []
    private(set) var unreadCounts: [String: Int] = [:]
    private(set) var connectionState: ConnectionState = .idle
    private(set) var lastRefresh: Date?
    /// Adresse fraîchement copiée (pour le toast « Copiée » dans l'UI).
    var lastCopiedAddress: String?

    let settings = IMAPSettings()

    private let store = AddressStore()
    private let service = MailboxService()
    private var pollTask: Task<Void, Never>?
    private var lastCleanup: Date = .distantPast

    private let defaults = UserDefaults.standard

    private var lastSeenUID: UInt32 {
        get { UInt32(defaults.integer(forKey: "lastSeenUID")) }
        set { defaults.set(Int(newValue), forKey: "lastSeenUID") }
    }

    private var storedUIDValidity: UInt32 {
        get { UInt32(defaults.integer(forKey: "uidValidity")) }
        set { defaults.set(Int(newValue), forKey: "uidValidity") }
    }

    init() {
        addresses = store.load()
        NotificationService.requestAuthorization()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: - Adresses

    @discardableResult
    func createAddress() -> TempAddress? {
        // Pas de domaine tant que l'identifiant IMAP n'est pas configuré.
        guard !settings.domain.isEmpty else { return nil }
        let address = AddressGenerator.generate(
            domain: settings.domain,
            existing: Set(addresses.map(\.address))
        )
        let temp = TempAddress(address: address, createdAt: Date())
        addresses.insert(temp, at: 0)
        store.save(addresses)
        copyToClipboard(address)

        // Des mails pour cette adresse peuvent déjà exister dans « autres ».
        rebucket()
        return temp
    }

    func copyToClipboard(_ address: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        lastCopiedAddress = address
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.lastCopiedAddress == address { self?.lastCopiedAddress = nil }
        }
    }

    func removeAddress(_ temp: TempAddress) {
        addresses.removeAll { $0.address == temp.address }
        store.save(addresses)
        unreadCounts[temp.address] = nil
        rebucket()
    }

    func markRead(_ address: String) {
        unreadCounts[address] = 0
    }

    func mails(for address: String) -> [MailSummary] {
        mailsByAddress[address] ?? []
    }

    var totalUnread: Int {
        unreadCounts.values.reduce(0, +)
    }

    // MARK: - Polling

    func refreshNow() {
        Task { await tick() }
    }

    /// Force un rechargement complet au prochain tick (après changement de réglages).
    func resetAndRefresh() {
        lastSeenUID = 0
        storedUIDValidity = 0
        connectionState = .idle
        refreshNow()
    }

    private func tick() async {
        guard let config = settings.makeConfig() else {
            connectionState = .missingPassword
            return
        }
        do {
            if storedUIDValidity == 0 {
                try await fullRefresh(config: config)
            } else {
                let snapshot = try await service.fetchNew(config: config, sinceUID: lastSeenUID)
                if snapshot.uidValidity != storedUIDValidity {
                    // La boîte a été recréée côté serveur : les UID ne sont plus comparables.
                    try await fullRefresh(config: config)
                } else {
                    ingest(snapshot.infos, notify: true)
                    advanceLastSeen(with: snapshot.infos)
                }
            }
            connectionState = .ok
            lastRefresh = Date()
            await runCleanupIfDue(config: config)
        } catch {
            connectionState = classify(error)
        }
    }

    private func fullRefresh(config: Config) async throws {
        let snapshot = try await service.fetchRecent(config: config)
        mailsByAddress = [:]
        otherMails = []
        ingest(snapshot.infos, notify: false)
        storedUIDValidity = snapshot.uidValidity
        lastSeenUID = 0
        advanceLastSeen(with: snapshot.infos)
    }

    private typealias Config = MailboxService.Config

    private func advanceLastSeen(with infos: [MessageInfo]) {
        let maxUID = infos.compactMap { $0.uid?.value }.max() ?? 0
        if maxUID > lastSeenUID { lastSeenUID = maxUID }
    }

    private func ingest(_ infos: [MessageInfo], notify: Bool) {
        let tracked = Set(addresses.map { $0.address.lowercased() })
        let knownUIDs = Set(mailsByAddress.values.joined().map(\.uid))
            .union(otherMails.map(\.uid))

        for info in infos {
            let recipient = RecipientExtractor.extract(
                from: info,
                domain: settings.domain,
                catchallAddress: settings.username,
                tracked: tracked
            )
            guard let summary = MailSummary(info: info, recipient: recipient),
                  !knownUIDs.contains(summary.uid) else { continue }

            if let recipient, tracked.contains(recipient) {
                mailsByAddress[recipient, default: []].append(summary)
                if notify {
                    unreadCounts[recipient, default: 0] += 1
                    NotificationService.postNewMail(address: recipient,
                                                    from: summary.from,
                                                    subject: summary.subject,
                                                    uid: summary.uid)
                }
            } else {
                otherMails.append(summary)
            }
        }

        for key in mailsByAddress.keys {
            mailsByAddress[key]?.sort { $0.date > $1.date }
        }
        otherMails.sort { $0.date > $1.date }
    }

    /// Redistribue tous les mails connus entre les adresses suivies et « autres ».
    private func rebucket() {
        let all = mailsByAddress.values.joined() + otherMails
        let tracked = Set(addresses.map { $0.address.lowercased() })
        var byAddress: [String: [MailSummary]] = [:]
        var others: [MailSummary] = []
        for mail in all {
            if let recipient = mail.recipient, tracked.contains(recipient) {
                byAddress[recipient, default: []].append(mail)
            } else {
                others.append(mail)
            }
        }
        for key in byAddress.keys {
            byAddress[key]?.sort { $0.date > $1.date }
        }
        others.sort { $0.date > $1.date }
        mailsByAddress = byAddress
        otherMails = others
    }

    // MARK: - Contenu

    func fetchContent(of summary: MailSummary) async throws -> MailContent {
        guard let config = settings.makeConfig() else {
            throw NSError(domain: "TempMail", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Identifiants IMAP manquants."])
        }
        return try await service.fetchContent(config: config, of: summary.info)
    }

    // MARK: - Nettoyage

    private func runCleanupIfDue(config: Config) async {
        guard settings.cleanupEnabled,
              Date().timeIntervalSince(lastCleanup) > 3600 else { return }
        lastCleanup = Date()
        let cutoff = Date().addingTimeInterval(-Double(settings.cleanupHours) * 3600)
        do {
            let deleted = try await service.deleteMessages(config: config, olderThan: cutoff)
            if deleted > 0 {
                for key in mailsByAddress.keys {
                    mailsByAddress[key]?.removeAll { $0.date < cutoff }
                }
                otherMails.removeAll { $0.date < cutoff }
            }
        } catch {
            // Non bloquant : retenté dans une heure.
        }
    }

    // MARK: - Réglages

    func testConnection(host: String, port: Int, username: String, password: String) async -> Result<Void, Error> {
        let config = Config(host: host, port: port, username: username, password: password)
        do {
            try await service.verify(config: config)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private func classify(_ error: Error) -> ConnectionState {
        let text = String(describing: error).lowercased()
        if text.contains("login") || text.contains("auth") {
            return .authFailed(error.localizedDescription)
        }
        return .offline(error.localizedDescription)
    }
}
