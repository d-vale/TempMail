import Foundation
import SwiftMail

/// Retrouve l'adresse réellement visée par un mail arrivé dans la boîte catch-all.
///
/// Chez certains hébergeurs, `Delivered-To` est réécrit en `catchall@…` et
/// `X-Original-To` est absent — l'adresse réelle est alors dans le `To`
/// d'enveloppe. Les en-têtes restent consultés en premier par robustesse, en
/// ignorant toute valeur égale à l'adresse catch-all.
enum RecipientExtractor {

    static func extract(from info: MessageInfo,
                        domain: String,
                        catchallAddress: String,
                        tracked: Set<String>) -> String? {
        let domainSuffix = "@" + domain.lowercased()
        let catchall = catchallAddress.lowercased()

        // 1. En-têtes de livraison (clés renvoyées en minuscules par SwiftMail).
        if let fields = info.additionalFields {
            let lowered = Dictionary(uniqueKeysWithValues: fields.map { ($0.key.lowercased(), $0.value) })
            for key in ["x-original-to", "delivered-to", "envelope-to", "x-envelope-to"] {
                if let raw = lowered[key] {
                    let candidate = normalize(raw)
                    if candidate != catchall, candidate.hasSuffix(domainSuffix) {
                        return candidate
                    }
                }
            }
        }

        // 2. Adresses du domaine dans To puis Cc ; préférer une adresse suivie.
        for list in [info.to, info.cc] {
            let candidates = list.map(normalize)
                .filter { $0 != catchall && $0.hasSuffix(domainSuffix) }
            if let match = candidates.first(where: { tracked.contains($0) }) ?? candidates.first {
                return match
            }
        }

        // 3. Mail adressé directement à la boîte catch-all, ou BCC pur : inattribuable.
        return nil
    }

    /// Extrait l'adresse nue d'une valeur du type `"Nom" <adresse@domaine>`.
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = trimmed.lastIndex(of: "<"), let close = trimmed.lastIndex(of: ">"), open < close {
            return String(trimmed[trimmed.index(after: open)..<close])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
        }
        return trimmed.lowercased()
    }
}
