
import Foundation

// MARK: - Main Estimate Structure

struct Estimate: Identifiable, Codable {
    let id: UUID
    let projectName: String
    let totalCost: Double
    let generatedAt: Date
    let sections: [EstimateSection]
}

// MARK: - Estimate Section

struct EstimateSection: Identifiable, Codable {
    let id: UUID
    let trade: String // e.g., "Demolition", "Framing", "Electrical"
    let lineItems: [LineItem]
    var sectionTotal: Double {
        lineItems.reduce(0) { $0 + $1.totalCost }
    }
}

// MARK: - Line Item

struct LineItem: Identifiable, Codable {
    let id: UUID
    let description: String
    let quantity: Double
    let unit: String // e.g., "sq ft", "each", "ln ft"
    let unitCost: Double
    let totalCost: Double
    let supplier: Supplier?
}

// MARK: - Supplier

struct Supplier: Codable {
    let name: String
    let logoName: String // Name of the image asset for the logo
}

// MARK: - Mock Data Generator

struct MockEstimateGenerator {
    static func generate() -> Estimate {
        let demolitionItems = [
            LineItem(id: UUID(), description: "Remove carpet and padding", quantity: 108, unit: "sq ft", unitCost: 0.50, totalCost: 54.00, supplier: nil),
            LineItem(id: UUID(), description: "Remove existing baseboards", quantity: 42, unit: "ln ft", unitCost: 0.75, totalCost: 31.50, supplier: nil)
        ]
        
        let framingItems = [
            LineItem(id: UUID(), description: "Wall framing inspection", quantity: 1, unit: "each", unitCost: 150.00, totalCost: 150.00, supplier: nil)
        ]
        
        let electricalItems = [
            LineItem(id: UUID(), description: "Install new ceiling fan box", quantity: 1, unit: "each", unitCost: 250.00, totalCost: 250.00, supplier: .lowes),
            LineItem(id: UUID(), description: "Standard outlet", quantity: 4, unit: "each", unitCost: 75.00, totalCost: 300.00, supplier: .homeDepot)
        ]
        
        let paintingItems = [
            LineItem(id: UUID(), description: "Paint walls (2 coats)", quantity: 336, unit: "sq ft", unitCost: 1.25, totalCost: 420.00, supplier: .sherwinWilliams),
            LineItem(id: UUID(), description: "Paint ceiling", quantity: 108, unit: "sq ft", unitCost: 1.00, totalCost: 108.00, supplier: .sherwinWilliams)
        ]
        
        let sections = [
            EstimateSection(id: UUID(), trade: "Demolition", lineItems: demolitionItems),
            EstimateSection(id: UUID(), trade: "Framing", lineItems: framingItems),
            EstimateSection(id: UUID(), trade: "Electrical", lineItems: electricalItems),
            EstimateSection(id: UUID(), trade: "Painting", lineItems: paintingItems)
        ]
        
        let totalCost = sections.reduce(0) { $0 + $1.sectionTotal }
        
        return Estimate(
            id: UUID(),
            projectName: "Project 42",
            totalCost: totalCost,
            generatedAt: Date(),
            sections: sections
        )
    }
}

extension Supplier {
    static let homeDepot = Supplier(name: "Home Depot", logoName: "homedepot_logo")
    static let lowes = Supplier(name: "Lowe's", logoName: "lowes_logo")
    static let sherwinWilliams = Supplier(name: "Sherwin-Williams", logoName: "sherwin_logo")
}
