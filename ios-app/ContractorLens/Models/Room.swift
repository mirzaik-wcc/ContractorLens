import Foundation
import ARKit

struct Room: Identifiable, Codable {
    let id: UUID
    var dimensions: RoomDimensions
    var surfaces: [Surface]
    var detectedMaterials: [String]
    
    init(id: UUID = UUID(), dimensions: RoomDimensions, surfaces: [Surface] = [], detectedMaterials: [String] = []) {
        self.id = id
        self.dimensions = dimensions
        self.surfaces = surfaces
        self.detectedMaterials = detectedMaterials
    }
}

