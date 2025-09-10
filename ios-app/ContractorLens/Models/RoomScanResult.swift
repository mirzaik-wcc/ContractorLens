import Foundation
import ARKit
import simd
import Darwin
import UIKit

// MARK: - Room Scan Result Types
struct RoomScanResult: Identifiable, Codable {
    let scanId: UUID
    let roomType: RoomType
    let dimensions: RoomDimensions
    let surfaces: [Surface]
    let arFrames: [ProcessedFrame]
    let metadata: ScanMetadata
    
    var id: UUID { scanId }
    
    init(scanId: UUID = UUID(), roomType: RoomType, dimensions: RoomDimensions, surfaces: [Surface], arFrames: [ProcessedFrame] = [], metadata: ScanMetadata) {
        self.scanId = scanId
        self.roomType = roomType
        self.dimensions = dimensions
        self.surfaces = surfaces
        self.arFrames = arFrames
        self.metadata = metadata
    }
}

// MARK: - Room Type Enumeration
enum RoomType: String, CaseIterable, Codable {
    case kitchen = "kitchen"
    case bathroom = "bathroom"
    case livingRoom = "living_room"
    case bedroom = "bedroom"
    case office = "office"
    case diningRoom = "dining_room"
    case laundryRoom = "laundry_room"
    case basement = "basement"
    case garage = "garage"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .kitchen: return "Kitchen"
        case .bathroom: return "Bathroom"
        case .livingRoom: return "Living Room"
        case .bedroom: return "Bedroom"
        case .office: return "Office"
        case .diningRoom: return "Dining Room"
        case .laundryRoom: return "Laundry Room"
        case .basement: return "Basement"
        case .garage: return "Garage"
        case .other: return "Other"
        }
    }
}

// MARK: - Scan Metadata
struct ScanMetadata: Codable {
    let startTime: Date
    let endTime: Date
    let frameCount: Int
    let deviceModel: String
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    init(startTime: Date = Date(), endTime: Date = Date(), frameCount: Int = 0, deviceModel: String = UIDevice.current.model) {
        self.startTime = startTime
        self.endTime = endTime
        self.frameCount = frameCount
        self.deviceModel = deviceModel
    }
}

enum ScanQuality: String, Codable {
    case low = "low"
    case standard = "standard"
    case high = "high"
    case premium = "premium"
}

// MARK: - Location Data
struct LocationData: Codable {
    let zipCode: String
    let city: String
    let state: String
    let coordinates: Coordinates?
    
    static let defaultLocation = LocationData(
        zipCode: "94105",
        city: "San Francisco",
        state: "CA",
        coordinates: Coordinates(latitude: 37.7749, longitude: -122.4194)
    )
    
    init(zipCode: String, city: String, state: String, coordinates: Coordinates? = nil) {
        self.zipCode = zipCode
        self.city = city
        self.state = state
        self.coordinates = coordinates
    }
}

struct Coordinates: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Processed Frame for AR Analysis
struct ProcessedFrame: Identifiable, Codable {
    let id = UUID()
    let imageData: Data
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, imageData, timestamp
    }
    
    init(imageData: Data, timestamp: Date) {
        self.imageData = imageData
        self.timestamp = timestamp
    }
}

// MARK: - Camera Transform Wrapper (for Codable conformance)
struct CameraTransform: Codable {
    let m00, m01, m02, m03: Float
    let m10, m11, m12, m13: Float
    let m20, m21, m22, m23: Float
    let m30, m31, m32, m33: Float
    
    init(matrix: simd_float4x4) {
        m00 = matrix.columns.0.x; m01 = matrix.columns.0.y; m02 = matrix.columns.0.z; m03 = matrix.columns.0.w
        m10 = matrix.columns.1.x; m11 = matrix.columns.1.y; m12 = matrix.columns.1.z; m13 = matrix.columns.1.w
        m20 = matrix.columns.2.x; m21 = matrix.columns.2.y; m22 = matrix.columns.2.z; m23 = matrix.columns.2.w
        m30 = matrix.columns.3.x; m31 = matrix.columns.3.y; m32 = matrix.columns.3.z; m33 = matrix.columns.3.w
    }
    
    var matrix: simd_float4x4 {
        return simd_float4x4(
            simd_float4(m00, m01, m02, m03),
            simd_float4(m10, m11, m12, m13),
            simd_float4(m20, m21, m22, m23),
            simd_float4(m30, m31, m32, m33)
        )
    }
}

// MARK: - Processing Metadata
struct ProcessingMetadata: Codable {
    let originalSize: Int
    let compressedSize: Int
    let compressionRatio: Double
    let timestamp: Date
    
    init(originalSize: Int, compressedSize: Int, compressionRatio: Double, timestamp: Date = Date()) {
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.compressionRatio = compressionRatio
        self.timestamp = timestamp
    }
}

// MARK: - Extensions
extension UIDevice {
    static var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            let scalar = UnicodeScalar(UInt8(value))
            return identifier + String(scalar)
        }
        return identifier
    }
}