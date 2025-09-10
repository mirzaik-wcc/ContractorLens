import Foundation
import SwiftUI
import ARKit
import Darwin

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    var formattedMeasurement: String {
        return String(format: "%.1f", self)
    }
}

extension Float {
    var formattedMeasurement: String {
        return String(format: "%.1f", self)
    }
}

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        alert("Error", isPresented: .constant(message.wrappedValue != nil)) {
            Button("OK") {
                message.wrappedValue = nil
            }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
    
    func loadingOverlay(_ isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                .ignoresSafeArea()
            }
        }
    }
}

extension Color {
    static let contractorBlue = Color(red: 0.2, green: 0.5, blue: 0.8)
    static let contractorGreen = Color(red: 0.2, green: 0.7, blue: 0.4)
    static let contractorOrange = Color(red: 0.9, green: 0.6, blue: 0.2)
    static let contractorRed = Color(red: 0.8, green: 0.3, blue: 0.3)
    
    static let surfaceFloor = Color.brown.opacity(0.7)
    static let surfaceCeiling = Color.gray.opacity(0.7)
    static let surfaceWall = Color.blue.opacity(0.7)
    static let surfaceWindow = Color.cyan.opacity(0.7)
    static let surfaceDoor = Color.orange.opacity(0.7)
}

extension Array where Element == AssemblyComponent {
    var totalMaterialCost: Double {
        reduce(0) { $0 + $1.materialCost }
    }
    
    var totalLaborCost: Double {
        reduce(0) { $0 + $1.laborCost }
    }
    
    var totalCost: Double {
        reduce(0) { $0 + $1.totalCost }
    }
    
    var totalLaborHours: Double {
        reduce(0) { $0 + ($1.quantity * $1.laborHoursPerUnit) }
    }
}

extension Array where Element == Assembly {
    var combinedTotalCost: Double {
        reduce(0) { total, assembly in
            total + assembly.components.totalCost
        }
    }
    
    var combinedLaborHours: Double {
        reduce(0) { total, assembly in
            total + assembly.components.totalLaborHours
        }
    }
}

extension Date {
    var formattedForDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var formattedForFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: self)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isNotEmpty: Bool {
        !isEmpty && !trimmed.isEmpty
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}

extension FileManager {
    var documentsDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func saveToDocuments<T: Codable>(_ object: T, filename: String) throws {
        let url = documentsDirectory.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(object)
        try data.write(to: url)
    }
    
    func loadFromDocuments<T: Codable>(_ type: T.Type, filename: String) throws -> T {
        let url = documentsDirectory.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}

extension Measurement {
    static let zero = Measurement(type: .length, value: 0, unit: .feet)
    
    var displayValue: String {
        switch unit {
        case .feet, .meters, .inches:
            return "\(value.formattedMeasurement) \(unit.rawValue)"
        case .squareFeet, .squareMeters:
            return "\(value.formattedMeasurement) \(unit.rawValue)"
        case .cubicFeet, .cubicMeters:
            return "\(value.formattedMeasurement) \(unit.rawValue)"
        }
    }
}

struct DeviceCapabilities {
    static var supportsLiDAR: Bool {
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    static var supportsRoomPlan: Bool {
        return false // RoomPlan removed for compatibility
    }
    
    static var supportsARKit: Bool {
        return ARWorldTrackingConfiguration.isSupported
    }
    
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

