import Foundation
import ARKit
import RoomPlan
import SwiftUI

class ARCoordinator: NSObject, ObservableObject {
    @Published var arViewContainer: ARViewContainer?
    @Published var isARAvailable = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var sessionStatus: SessionStatus = .initializing
    
    private var arSession: ARSession?
    
    override init() {
        super.init()
        checkARAvailability()
    }
    
    private func checkARAvailability() {
        isARAvailable = ARWorldTrackingConfiguration.isSupported && 
                       RoomCaptureSession.isSupported
        
        if isARAvailable {
            sessionStatus = .ready
        } else {
            sessionStatus = .notSupported
        }
    }
    
    func createARViewContainer() -> ARViewContainer? {
        guard isARAvailable else { return nil }
        
        let container = ARViewContainer()
        self.arViewContainer = container
        return container
    }
    
    func startARSession() {
        guard isARAvailable else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        arSession = ARSession()
        arSession?.delegate = self
        arSession?.run(configuration)
        
        sessionStatus = .running
    }
    
    func pauseARSession() {
        arSession?.pause()
        sessionStatus = .paused
    }
    
    func resetARSession() {
        guard let session = arSession else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sessionStatus = .running
    }
    
    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

extension ARCoordinator: ARSessionDelegate {
    private func session(_ session: ARSession, didChange trackingState: ARCamera.TrackingState) {
        DispatchQueue.main.async {
            self.trackingState = trackingState
            
            switch trackingState {
            case .normal:
                self.sessionStatus = .running
            case .limited(_):
                self.sessionStatus = .limited
            case .notAvailable:
                self.sessionStatus = .interrupted
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.sessionStatus = .failed(error.localizedDescription)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.sessionStatus = .interrupted
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.sessionStatus = .running
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @StateObject private var coordinator = ARCoordinator()
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
    }
    
    func makeCoordinator() -> ARCoordinator {
        return coordinator
    }
}

enum SessionStatus {
    case initializing
    case ready
    case running
    case paused
    case interrupted
    case limited
    case failed(String)
    case notSupported
    
    var description: String {
        switch self {
        case .initializing:
            return "Initializing AR session..."
        case .ready:
            return "Ready to start scanning"
        case .running:
            return "AR session running"
        case .paused:
            return "AR session paused"
        case .interrupted:
            return "AR session interrupted"
        case .limited:
            return "AR tracking limited"
        case .failed(let error):
            return "AR session failed: \(error)"
        case .notSupported:
            return "AR not supported on this device"
        }
    }
    
    var isScanning: Bool {
        switch self {
        case .running:
            return true
        default:
            return false
        }
    }
}

extension ARCamera.TrackingState {
    var description: String {
        switch self {
        case .normal:
            return "Normal tracking"
        case .limited(let reason):
            return "Limited tracking: \(reason.description)"
        case .notAvailable:
            return "Tracking not available"
        }
    }
}

extension ARCamera.TrackingState.Reason {
    var description: String {
        switch self {
        case .initializing:
            return "Initializing"
        case .excessiveMotion:
            return "Move more slowly"
        case .insufficientFeatures:
            return "Point camera at surfaces with more detail"
        case .relocalizing:
            return "Relocalizing..."
        @unknown default:
            return "Unknown tracking issue"
        }
    }
}