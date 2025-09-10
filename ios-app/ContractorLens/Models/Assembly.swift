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