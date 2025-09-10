import Foundation
import Combine

@MainActor
class AssemblyViewModel: ObservableObject {
    @Published var assemblies: [Assembly] = []
    @Published var selectedAssembly: Assembly?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalEstimate: Double = 0.0
    
    private let assemblyService: AssemblyEngineService
    private var cancellables = Set<AnyCancellable>()
    
    init(assemblyService: AssemblyEngineService = AssemblyEngineService()) {
        self.assemblyService = assemblyService
        setupBindings()
    }
    
    private func setupBindings() {
        assemblyService.$assemblies
            .sink { [weak self] assemblies in
                self?.assemblies = assemblies
                self?.calculateTotalEstimate()
            }
            .store(in: &cancellables)
        
        assemblyService.$isLoading
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
        
        assemblyService.$errorMessage
            .sink { [weak self] errorMessage in
                self?.errorMessage = errorMessage
            }
            .store(in: &cancellables)
    }
    
    func processRoom(_ room: Room) {
        assemblyService.processRoom(room)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] assemblies in
                    self?.assemblies = assemblies
                }
            )
            .store(in: &cancellables)
    }
    
    func selectAssembly(_ assembly: Assembly) {
        selectedAssembly = assembly
    }
    
    func deselectAssembly() {
        selectedAssembly = nil
    }
    
    func toggleAssemblySelection(_ assembly: Assembly) {
        if selectedAssembly?.id == assembly.id {
            deselectAssembly()
        } else {
            selectAssembly(assembly)
        }
    }
    
    func exportAssembly(_ assembly: Assembly) -> Data? {
        return assemblyService.exportAssemblyData(assembly)
    }
    
    func exportAllAssemblies() -> Data? {
        let exportData = AssemblyExport(
            assemblies: assemblies,
            totalCost: totalEstimate,
            timestamp: Date()
        )
        
        do {
            return try JSONEncoder().encode(exportData)
        } catch {
            errorMessage = "Failed to export assembly data: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func calculateTotalEstimate() {
        totalEstimate = assemblies.reduce(0) { total, assembly in
            total + assembly.components.reduce(0) { $0 + $1.totalCost }
        }
    }
    
    func getAssemblyBreakdown(for assembly: Assembly) -> AssemblyBreakdown {
        let materialCost = assembly.components.reduce(0) { $0 + $1.materialCost }
        let laborCost = assembly.components.reduce(0) { $0 + $1.laborCost }
        let totalLaborHours = assembly.components.reduce(0) { $0 + ($1.quantity * $1.laborHoursPerUnit) }
        
        return AssemblyBreakdown(
            materialCost: materialCost,
            laborCost: laborCost,
            totalCost: materialCost + laborCost,
            laborHours: totalLaborHours
        )
    }
    
    func getComponentsGroupedByType(for assembly: Assembly) -> [String: [AssemblyComponent]] {
        Dictionary(grouping: assembly.components) { component in
            if component.laborHoursPerUnit > 0 {
                return "Labor"
            } else {
                return "Materials"
            }
        }
    }
    
    var hasAssemblies: Bool {
        !assemblies.isEmpty
    }
    
    var isEmpty: Bool {
        assemblies.isEmpty && !isLoading
    }
}

struct AssemblyBreakdown {
    let materialCost: Double
    let laborCost: Double
    let totalCost: Double
    let laborHours: Double
}

struct AssemblyExport: Codable {
    let assemblies: [Assembly]
    let totalCost: Double
    let timestamp: Date
    var version: String = "1.0"
    
    init(assemblies: [Assembly], totalCost: Double, timestamp: Date) {
        self.assemblies = assemblies
        self.totalCost = totalCost
        self.timestamp = timestamp
    }
}