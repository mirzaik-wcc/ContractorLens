import Foundation
import Combine

class AssemblyEngineService: ObservableObject {
    @Published var assemblies: [Assembly] = []
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var lastEstimate: EstimateResponse?
    @Published var error: ServiceError?
    @Published var errorMessage: String?
    
    private let baseURL = "http://localhost:3000/api/v1"  // Backend endpoint
    private let session = URLSession.shared
    var cancellables = Set<AnyCancellable>()
    
    enum ServiceError: LocalizedError, Identifiable {
        case networkError(String)
        case serverError(Int, String)
        case decodingError
        case invalidData
        
        var id: String { localizedDescription }
        
        var errorDescription: String? {
            switch self {
            case .networkError(let message):
                return "Network Error: \(message)"
            case .serverError(let code, let message):
                return "Server Error (\(code)): \(message)"
            case .decodingError:
                return "Failed to process server response"
            case .invalidData:
                return "Invalid scan data"
            }
        }
    }
    
    func generateEstimate(from scanResult: RoomScanResult, 
                         userPreferences: UserPreferences,
                         location: LocationData) -> AnyPublisher<EstimateResponse, ServiceError> {
        
        guard let url = URL(string: "\(baseURL)/estimates") else {
            return Fail(error: ServiceError.invalidData)
                .eraseToAnyPublisher()
        }
        
        let estimateRequest = EstimateRequest(
            roomData: scanResult,
            userPreferences: userPreferences,
            location: location
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(estimateRequest)
        } catch {
            return Fail(error: ServiceError.invalidData)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ServiceError.networkError("Invalid response")
                }
                
                if httpResponse.statusCode >= 400 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw ServiceError.serverError(httpResponse.statusCode, errorMessage)
                }
                
                return data
            }
            .decode(type: EstimateResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return ServiceError.decodingError
                } else if let serviceError = error as? ServiceError {
                    return serviceError
                } else {
                    return ServiceError.networkError(error.localizedDescription)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func submitGeminiAnalysis(frames: [ProcessedFrame], 
                             roomType: RoomType,
                             dimensions: RoomDimensions) -> AnyPublisher<GeminiAnalysisResponse, ServiceError> {
        
        guard let url = URL(string: "\(baseURL)/analysis") else {
            return Fail(error: ServiceError.invalidData)
                .eraseToAnyPublisher()
        }
        
        let encodedFrames = frames.map { $0.imageData.base64EncodedString() }
        let roomContext = RoomContext(type: roomType, dimensions: dimensions, surfaces: []) // Surfaces are not available in this function

        let analysisRequest = GeminiAnalysisRequest(
            images: encodedFrames,
            roomContext: roomContext,
            analysisLevel: .standard
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(analysisRequest)
        } catch {
            return Fail(error: ServiceError.invalidData)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode < 400 else {
                    throw ServiceError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, "Analysis failed")
                }
                return data
            }
            .decode(type: GeminiAnalysisResponse.self, decoder: JSONDecoder())
            .mapError { error in
                error is DecodingError ? ServiceError.decodingError : ServiceError.networkError(error.localizedDescription)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func processRoom(_ room: Room) -> AnyPublisher<[Assembly], Error> {
        isLoading = true
        errorMessage = nil
        
        return Future { [weak self] promise in
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    let mockAssemblies = self?.generateMockAssemblies(for: room) ?? []
                    self?.assemblies = mockAssemblies
                    promise(.success(mockAssemblies))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func generateMockAssemblies(for room: Room) -> [Assembly] {
        let floorArea = room.dimensions.area
        let wallArea = room.surfaces.filter { $0.type == .wall }.reduce(0) { $0 + $1.area }
        
        var flooringAssembly = Assembly(name: "Hardwood Flooring Installation", room: room)
        flooringAssembly.components = [
            AssemblyComponent(
                name: "Hardwood Flooring",
                quantity: floorArea,
                unit: "sq ft",
                unitCost: 8.50,
                laborHoursPerUnit: 0.5,
                laborRate: 45.0
            ),
            AssemblyComponent(
                name: "Underlayment",
                quantity: floorArea,
                unit: "sq ft",
                unitCost: 1.25
            )
        ]
        
        var paintingAssembly = Assembly(name: "Interior Painting", room: room)
        paintingAssembly.components = [
            AssemblyComponent(
                name: "Premium Paint",
                quantity: wallArea / 350,
                unit: "gallon",
                unitCost: 65.0
            ),
            AssemblyComponent(
                name: "Primer",
                quantity: wallArea / 400,
                unit: "gallon",
                unitCost: 45.0
            ),
            AssemblyComponent(
                name: "Painting Labor",
                quantity: wallArea,
                unit: "sq ft",
                unitCost: 0.0,
                laborHoursPerUnit: 0.02,
                laborRate: 42.0
            )
        ]
        
        return [flooringAssembly, paintingAssembly]
    }
    
    func calculateTotalCost(for assemblies: [Assembly]) -> Double {
        return assemblies.reduce(0) { $0 + $1.totalCost }
    }
    
    func exportAssemblyData(_ assembly: Assembly) -> Data? {
        do {
            return try JSONEncoder().encode(assembly)
        } catch {
            errorMessage = "Failed to export assembly data: \(error.localizedDescription)"
            return nil
        }
    }
}

// MARK: - Request/Response Models

struct EstimateRequest: Codable {
    let roomData: RoomScanResult
    let userPreferences: UserPreferences
    let location: LocationData
}

struct GeminiAnalysisRequest: Codable {
    let images: [String]
    let roomContext: RoomContext
    let analysisLevel: AnalysisLevel
}

struct GeminiAnalysisResponse: Codable {
    let surfaces: [DetectedSurface]
    let materials: [DetectedMaterial]
    let confidence: Double
    let recommendedQualityTier: String
}

struct RoomContext: Codable {
    let type: RoomType
    let dimensions: RoomDimensions
    let surfaces: [Surface]
}

enum AnalysisLevel: String, Codable {
    case basic, standard, professional
}

struct DetectedSurface: Codable {
    let type: String
    let area: Double
    let condition: String
}

struct DetectedMaterial: Codable {
    let name: String
    let confidence: Double
    let area: Double
}




