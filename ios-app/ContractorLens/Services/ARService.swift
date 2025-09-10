import ARKit
import Combine
import SwiftUI

@MainActor
class ARService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var roomData: Room?
    @Published var scanProgress: Float = 0.0
    @Published var errorMessage: String?
    
    private var arSession: ARSession?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupARSession()
    }
    
    private func setupARSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            errorMessage = "ARKit World Tracking is not supported on this device"
            return
        }
        
        arSession = ARSession()
    }
    
    func startRoomCapture() {
        guard !isScanning else { return }
        
        errorMessage = nil
        isScanning = true
        scanProgress = 0.0
        
        let config = ARWorldTrackingConfiguration()
        arSession?.run(config)
        
        simulateCapture()
    }
    
    func stopRoomCapture() {
        guard isScanning else { return }
        
        arSession?.pause()
        isScanning = false
        scanProgress = 0.0
    }
    
    private func simulateCapture() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.scanProgress = 1.0
            self.processRoomData()
            self.isScanning = false
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.isScanning = false
            self.scanProgress = 0.0
        }
    }
    
    func resetSession() {
        stopRoomCapture()
        roomData = nil
        errorMessage = nil
        scanProgress = 0.0
    }
    
    private func processRoomData() {
        let dimensions = RoomDimensions(
            length: 10.0,
            width: 12.0,
            height: 8.0
        )
        
        let surfaces: [Surface] = [
            Surface(type: .floor, area: dimensions.area),
            Surface(type: .ceiling, area: dimensions.area),
            Surface(type: .wall, area: dimensions.height * dimensions.length * 2 + dimensions.height * dimensions.width * 2)
        ]
        
        self.roomData = Room(
            dimensions: dimensions,
            surfaces: surfaces,
            detectedMaterials: ["drywall", "hardwood"]
        )
    }
}