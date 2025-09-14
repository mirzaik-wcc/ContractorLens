import Foundation
import RoomPlan
import UIKit

// MARK: - Supporting Types
struct RoomScanData: Identifiable {
    let id: UUID
    let startTime: Date
    var status: ScanStatus
}

enum ScanStatus {
    case scanning, processing, completed, failed
}

@available(iOS 16.0, *)
@MainActor
class ScanningService: ObservableObject {
    @Published var currentScan: RoomScanData?
    
    let roomScanner = RoomScanner()
    private(set) var capturedFrames: [Data] = []
    
    func startNewScan(roomType: RoomType) -> UUID {
        let scanId = UUID()
        currentScan = RoomScanData(
            id: scanId,
            startTime: Date(),
            status: .scanning
        )
        
        // Reset frames for the new scan
        capturedFrames.removeAll()
        
        roomScanner.startCapture()
        return scanId
    }
    
    /// Called by the Coordinator to add a snapshot frame.
    func addCapturedFrame(imageData: Data) {
        capturedFrames.append(imageData)
    }
    
    /// Called when the RoomPlan session is finished and the final data is available.
    func completeScan() -> RoomScanResult? {
        print("🔵 ScanningService: Completing scan...")
        
        guard let scanData = currentScan, let capturedRoom = roomScanner.capturedRoom else {
            print("🔴 ERROR: Current scan or captured room data is nil.")
            return nil
        }
        
        let dimensions = getRoomDimensions(from: capturedRoom)
        let surfaces = getDetectedSurfaces(from: capturedRoom)
        
        let processedFrames = processFramesForGemini(capturedFrames)
        
        let result = RoomScanResult(
            scanId: scanData.id,
            roomType: .other, // RoomType is now generic
            dimensions: dimensions,
            surfaces: surfaces,
            arFrames: processedFrames,
            metadata: ScanMetadata(
                startTime: scanData.startTime,
                endTime: Date(),
                frameCount: capturedFrames.count,
                deviceModel: UIDevice.current.model
            )
        )
        
        print("✅ Scan completed successfully with \(processedFrames.count) frames.")
        currentScan = nil
        return result
    }
    
    func stopCurrentScan() {
        roomScanner.stopCapture()
        currentScan?.status = .processing
    }
    
    // MARK: - Data Processing Helpers
    
    private func getRoomDimensions(from room: CapturedRoom) -> RoomDimensions {
        let dims = room.boundingBox.max - room.boundingBox.min
        return RoomDimensions(length: Double(dims.x), width: Double(dims.y), height: Double(dims.z))
    }
    
    private func getDetectedSurfaces(from room: CapturedRoom) -> [Surface] {
        var surfaces: [Surface] = []
        
        for wall in room.walls {
            surfaces.append(Surface(type: .wall, area: Double(wall.dimensions.x * wall.dimensions.y), confidence: 0.9))
        }
        for door in room.doors {
            surfaces.append(Surface(type: .door, area: Double(door.dimensions.x * door.dimensions.y), confidence: 0.9))
        }
        for window in room.windows {
            surfaces.append(Surface(type: .window, area: Double(window.dimensions.x * window.dimensions.y), confidence: 0.9))
        }
        // You can add more object types as needed
        
        return surfaces
    }
    
    private func processFramesForGemini(_ frames: [Data]) -> [ProcessedFrame] {
        // Convert the captured JPEG data into the ProcessedFrame format
        return frames.map { frameData in
            return ProcessedFrame(
                imageData: frameData,
                timestamp: Date() // Timestamp could be refined if needed
            )
        }
    }
}