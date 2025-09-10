import Foundation

enum ItemCategory: String, Codable {
    case materials = "materials"
    case labor = "labor"
    case equipment = "equipment"
    case overhead = "overhead"
    case tax = "tax"
}