import Foundation

/// Une adresse temporaire générée — simple filtre d'affichage sur la boîte catch-all.
struct TempAddress: Codable, Identifiable, Hashable {
    var id: String { address }
    let address: String
    let createdAt: Date
}
