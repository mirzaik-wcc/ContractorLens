import Foundation

struct Assembly: Identifiable, Codable {
    let id: UUID
    var name: String
    var components: [AssemblyComponent]
    var totalCost: Double
    var laborHours: Double
    var room: Room?
    var timestamp: Date
    
    var materialCost: Double {
        components.reduce(0) { $0 + $1.materialCost }
    }
    
    var laborCost: Double {
        components.reduce(0) { $0 + $1.laborCost }
    }
    
    init(id: UUID = UUID(), name: String, components: [AssemblyComponent] = [], room: Room? = nil) {
        self.id = id
        self.name = name
        self.components = components
        self.totalCost = 0
        self.laborHours = 0
        self.room = room
        self.timestamp = Date()
    }
}

struct AssemblyComponent: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var unitCost: Double
    var laborHoursPerUnit: Double
    var laborRate: Double
    
    var materialCost: Double { quantity * unitCost }
    var laborCost: Double { quantity * laborHoursPerUnit * laborRate }
    var totalCost: Double { materialCost + laborCost }
    
    init(id: UUID = UUID(), name: String, quantity: Double, unit: String, unitCost: Double, laborHoursPerUnit: Double = 0, laborRate: Double = 0) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.unitCost = unitCost
        self.laborHoursPerUnit = laborHoursPerUnit
        self.laborRate = laborRate
    }
}

// MARK: - Main Estimate Structure (V2)

struct Estimate: Identifiable, Codable {
    let id = UUID()
    let subtotal: Double
    let materialTotal: Double
    let laborTotal: Double
    let markupAmount: Double
    let taxAmount: Double
    let grandTotal: Double
    let csiDivisions: [CSIDivision]
    let metadata: EstimateMetadata
    
    private enum CodingKeys: String, CodingKey {
        case subtotal, materialTotal, laborTotal, markupAmount, taxAmount, grandTotal, csiDivisions, metadata
    }
}

// MARK: - CSI Division

struct CSIDivision: Identifiable, Codable {
    let id = UUID()
    let csiCode: String
    let divisionName: String
    let totalCost: Double
    let laborHours: Double
    let lineItems: [LineItem]
    
    private enum CodingKeys: String, CodingKey {
        case csiCode = "csi_code"
        case divisionName = "division_name"
        case totalCost = "total_cost"
        case laborHours = "labor_hours"
        case lineItems = "line_items"
    }
}

// MARK: - Line Item (V2)

struct LineItem: Identifiable, Codable {
    let id = UUID()
    let itemId: String
    let csiCode: String
    let description: String
    let quantity: Double
    let unit: String
    let unitCost: Double
    let totalCost: Double
    let type: String // 'material', 'labor', 'equipment'
    let manufacturer: String?
    let modelNumber: String?
    let specifications: MaterialSpecification?
    let quantityDetails: QuantityDetails?
    let laborDetails: LaborDetails?
    
    private enum CodingKeys: String, CodingKey {
        case itemId, csiCode, description, quantity, unit, unitCost, totalCost, type, manufacturer, modelNumber, specifications, quantityDetails, laborDetails
    }
}

// MARK: - Detailed Breakdowns

struct MaterialSpecification: Codable {
    let specId: String
    let brandName: String?
    let colorFinish: String?
    let sizeDimensions: String?
    // Add other fields from the DB as needed
}

struct QuantityDetails: Codable {
    let baseQuantity: Double
    let totalQuantity: Double
    // Add other fields from the calculator service as needed
}

struct LaborDetails: Codable {
    let baseHours: Double
    let totalHours: Double
    let skillLevel: String?
    // Add other fields from the calculator service as needed
}

// MARK: - Metadata

struct EstimateMetadata: Codable {
    let totalLaborHours: Double
    let finishLevel: String
    let calculationDate: String
    let engineVersion: String
}
