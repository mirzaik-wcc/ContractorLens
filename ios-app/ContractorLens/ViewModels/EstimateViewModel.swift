
import Foundation
import Combine

@MainActor
class EstimateViewModel: ObservableObject {
    @Published var currentEstimate: Estimate?
    @Published var isLoading = false
    @Published var error: Error?

    private var cancellables = Set<AnyCancellable>()

    func generateEstimateWithGeminiAnalysis(from scanResult: RoomScanResult) {
        isLoading = true
        error = nil
        currentEstimate = nil

        // In a real app, you would send the scanResult to your backend here.
        // The backend would perform the Gemini analysis and return the structured estimate.
        
        // For now, we will simulate this process and use our mock data generator.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Simulate network delay
            let mockEstimate = MockEstimateGenerator.generate()
            self.currentEstimate = mockEstimate
            self.isLoading = false
        }
    }

    func clearError() {
        error = nil
    }

    func retry(with scanResult: RoomScanResult) {
        error = nil
        generateEstimateWithGeminiAnalysis(from: scanResult)
    }
    
    var hasError: Bool {
        return error != nil
    }
}
