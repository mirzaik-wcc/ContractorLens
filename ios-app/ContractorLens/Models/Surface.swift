import Foundation

struct Surface: Identifiable, Codable {
    let id: UUID
    var type: SurfaceType
    var area: Double
    var material: String?
    var dimensions: SurfaceDimensions?
    var confidence: Double
    
    init(id: UUID = UUID(), type: SurfaceType, area: Double, material: String? = nil, dimensions: SurfaceDimensions? = nil, confidence: Double = 1.0) {
        self.id = id
        self.type = type
        self.area = area
        self.material = material
        self.dimensions = dimensions
        self.confidence = confidence
    }
}

enum SurfaceType: String, CaseIterable, Codable {
    case wall, floor, ceiling, window, door
    
    var displayName: String {
        switch self {
        case .wall: return "Wall"
        case .floor: return "Floor"
        case .ceiling: return "Ceiling"
        case .window: return "Window"
        case .door: return "Door"
        }
    }
}

struct SurfaceDimensions: Codable {
    var width: Double
    var height: Double
    
    var area: Double { width * height }
    
    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}