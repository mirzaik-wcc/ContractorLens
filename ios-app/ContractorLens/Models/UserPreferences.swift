import Foundation

// MARK: - User Preferences
struct UserPreferences: Codable {
    var qualityTier: String
    var preferredLocation: LocationData
    var includeLabor: Bool
    var includeTax: Bool
    var taxRate: Double
    
    init(qualityTier: String = "standard", preferredLocation: LocationData = .defaultLocation, includeLabor: Bool = true, includeTax: Bool = true, taxRate: Double = 0.0875) {
        self.qualityTier = qualityTier
        self.preferredLocation = preferredLocation
        self.includeLabor = includeLabor
        self.includeTax = includeTax
        self.taxRate = taxRate
    }
    
    static let defaultPreferences = UserPreferences()
}