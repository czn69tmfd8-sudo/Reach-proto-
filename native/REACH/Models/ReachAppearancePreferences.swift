import Foundation

/// On-device presentation preferences, never a source of pairing identity.
struct ReachAppearancePreferences: Codable, Equatable {
    var ownName = ""
    var partnerName = ""
    var personalMessage = ""
    var showMessage = false
    var ownLabel: String { ownName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "You" : String(ownName.prefix(40)) }
    var partnerLabel: String { partnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your partner" : String(partnerName.prefix(40)) }
}
