import Foundation

/// Génère des adresses lisibles au format mot-mot-chiffres@domaine.
enum AddressGenerator {

    static func generate(domain: String, existing: Set<String>) -> String {
        for _ in 0..<50 {
            let w1 = words.randomElement()!
            var w2 = words.randomElement()!
            while w2 == w1 { w2 = words.randomElement()! }
            let candidate = "\(w1)-\(w2)-\(Int.random(in: 1000...9999))@\(domain)"
            if !existing.contains(candidate) { return candidate }
        }
        // Collision improbable après 50 essais : suffixe horodaté en dernier recours.
        return "mail-\(Int(Date().timeIntervalSince1970))@\(domain)"
    }

    static let words: [String] = [
        "acorn", "amber", "apple", "arrow", "aspen", "atlas", "azure",
        "badge", "bamboo", "basil", "beach", "berry", "birch", "blaze",
        "bloom", "breeze", "brick", "brook", "candle", "canoe", "canyon",
        "cedar", "chalk", "cherry", "cliff", "cloud", "clover", "cobalt",
        "comet", "copper", "coral", "cotton", "cove", "crane", "creek",
        "cricket", "crystal", "daisy", "dawn", "delta", "denim", "dune",
        "eagle", "ember", "fable", "falcon", "feather", "fern", "field",
        "finch", "flint", "forest", "fox", "frost", "garnet", "gecko",
        "ginger", "glacier", "glade", "grove", "harbor", "hazel", "heron",
        "hill", "holly", "honey", "ivory", "ivy", "jade", "jasper",
        "juniper", "kite", "lagoon", "lake", "lantern", "larch", "laurel",
        "lava", "leaf", "lemon", "lilac", "lily", "linen", "lotus",
        "lunar", "maple", "marble", "meadow", "mint", "mist", "moss",
        "night", "nutmeg", "oak", "ocean", "olive", "onyx", "opal",
        "orbit", "orchid", "otter", "owl", "palm", "pearl", "pebble",
        "penny", "peony", "pepper", "petal", "pine", "plum", "pond",
        "poppy", "prism", "quail", "quartz", "quill", "rain", "raven",
        "reef", "ridge", "river", "robin", "rocket", "rose", "rowan",
        "ruby", "rustic", "saffron", "sage", "salt", "sand", "sequoia",
        "shadow", "shell", "shore", "sierra", "silver", "sky", "slate",
        "snow", "solar", "sparrow", "spruce", "star", "stone", "storm",
        "stream", "summit", "sunny", "swan", "thyme", "tiger", "topaz",
        "torch", "trail", "tulip", "tundra", "valley", "velvet", "vine",
        "violet", "walnut", "wave", "willow", "wind", "winter", "wolf",
        "wren", "zephyr", "zinc", "zircon",
    ]
}
