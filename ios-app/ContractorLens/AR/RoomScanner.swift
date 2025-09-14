import Foundation
import RoomPlan
import Combine

@available(iOS 16.0, *)
@MainActor
class RoomScanner: NSObject, RoomCaptureSessionDelegate, ObservableObject {
    @Published var scanningState: ScanningState = .notStarted
    @Published var capturedRoom: CapturedRoom?
    @Published var errorMessage: String?
    @Published var scanProgress: Double = 0.0

    var session: RoomCaptureSession?
    
    enum ScanningState {
        case notStarted, scanning, completed, error(String)
    }
    
    override init() {
        super.init()
    }
    
    func startCapture() {
        guard RoomCaptureSession.isSupported else {
            print("❌ RoomPlan is not supported on this device.")
            self.scanningState = .error("RoomPlan is not supported on this device.")
            return
        }
        
        print("🔵 RoomScanner: Starting RoomPlan capture")
        session = RoomCaptureSession()
        session?.delegate = self
        session?.run(configuration: RoomCaptureSession.Configuration())
        scanningState = .scanning
    }
    
    func stopCapture() {
        session?.stop()
        // The delegate will handle the state change to .completed or .error
    }

    func reset() {
        stopCapture()
        scanningState = .notStarted
        capturedRoom = nil
        errorMessage = nil
        scanProgress = 0.0
    }
    
    // MARK: - RoomCaptureSessionDelegate
    
    func roomCaptureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        // This provides live updates, but we primarily care about the final result.
        // We could use this for live analysis in the future.
        DispatchQueue.main.async {
            self.capturedRoom = room
        }
    }
    
    func roomCaptureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        print("🔵 RoomScanner: Capture session ended.")
        DispatchQueue.main.async {
            if let error = error {
                print("❌ RoomScanner: Capture failed with error: \(error.localizedDescription)")
                self.scanningState = .error(error.localizedDescription)
                self.errorMessage = error.localizedDescription
                return
            }
            
            print("✅ RoomScanner: Capture succeeded.")
            self.capturedRoom = data.capturedRoom
            self.scanningState = .completed
        }
    }
}