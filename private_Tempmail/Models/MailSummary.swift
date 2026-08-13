import Foundation
import SwiftMail

/// Résumé d'un mail de la boîte catch-all, rattaché à son destinataire réel.
struct MailSummary: Identifiable {
    let uid: UInt32
    let subject: String
    let from: String
    let recipient: String?
    let date: Date
    /// Conservé pour pouvoir récupérer le corps complet à la demande.
    let info: MessageInfo

    var id: UInt32 { uid }

    init?(info: MessageInfo, recipient: String?) {
        guard let uid = info.uid?.value else { return nil }
        self.uid = uid
        self.subject = info.subject ?? "(sans sujet)"
        self.from = info.from ?? "(expéditeur inconnu)"
        self.recipient = recipient
        self.date = info.internalDate ?? info.date ?? Date()
        self.info = info
    }
}

extension MailSummary: Hashable {
    static func == (lhs: MailSummary, rhs: MailSummary) -> Bool { lhs.uid == rhs.uid }
    func hash(into hasher: inout Hasher) { hasher.combine(uid) }
}

/// Contenu complet d'un mail, extrait côté service pour rester Sendable.
struct MailContent: Sendable {
    let html: String?
    let text: String?
    let attachmentCount: Int
}
