import Foundation

/// Persistance locale des adresses générées : JSON Codable dans UserDefaults.
struct AddressStore {
    private let key = "trackedAddresses"

    func load() -> [TempAddress] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([TempAddress].self, from: data) else {
            return []
        }
        return list
    }

    func save(_ addresses: [TempAddress]) {
        if let data = try? JSONEncoder().encode(addresses) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
