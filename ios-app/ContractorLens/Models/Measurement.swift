import Foundation

struct RoomDimensions: Codable {
    var length: Double
    var width: Double
    var height: Double
    
    var area: Double { length * width }
    var volume: Double { length * width * height }
    
    init(length: Double, width: Double, height: Double) {
        self.length = length
        self.width = width
        self.height = height
    }
}

struct Measurement: Identifiable, Codable {
    let id: UUID
    var type: MeasurementType
    var value: Double
    var unit: MeasurementUnit
    var timestamp: Date
    
    init(id: UUID = UUID(), type: MeasurementType, value: Double, unit: MeasurementUnit = .feet) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = Date()
    }
}

enum MeasurementType: String, CaseIterable, Codable {
    case length, width, height, area, volume
}

enum MeasurementUnit: String, CaseIterable, Codable {
    case feet = "ft"
    case meters = "m"
    case inches = "in"
    case squareFeet = "sq ft"
    case squareMeters = "sq m"
    case cubicFeet = "cu ft"
    case cubicMeters = "cu m"
}