import SwiftUI

struct ResultsView: View {
    let room: Room
    @StateObject private var assemblyService = AssemblyEngineService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    RoomSummaryCard(room: room)
                    
                    SurfaceBreakdownCard(surfaces: room.surfaces)
                    
                    if assemblyService.isLoading {
                        LoadingAssembliesView()
                    } else if !assemblyService.assemblies.isEmpty {
                        AssembliesListView(assemblies: assemblyService.assemblies)
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Results")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAssemblies()
            }
        }
    }
    
    private func loadAssemblies() {
        assemblyService.processRoom(room)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &assemblyService.cancellables)
    }
}

struct RoomSummaryCard: View {
    let room: Room
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Room Dimensions")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Label("Length", systemImage: "ruler")
                    Text("\(room.dimensions.length, specifier: "%.1f") ft")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Label("Width", systemImage: "ruler")
                    Text("\(room.dimensions.width, specifier: "%.1f") ft")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Label("Height", systemImage: "arrow.up.and.down")
                    Text("\(room.dimensions.height, specifier: "%.1f") ft")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Label("Area", systemImage: "square.grid.3x3")
                    Text("\(room.dimensions.area, specifier: "%.0f") sq ft")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SurfaceBreakdownCard: View {
    let surfaces: [Surface]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Surface Breakdown")
                .font(.headline)
            
            ForEach(surfaces) { surface in
                HStack {
                    Label(surface.type.displayName, systemImage: surfaceIcon(for: surface.type))
                    Spacer()
                    Text("\(surface.area, specifier: "%.0f") sq ft")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func surfaceIcon(for type: SurfaceType) -> String {
        switch type {
        case .wall: return "rectangle.portrait"
        case .floor: return "square"
        case .ceiling: return "square.dashed"
        case .window: return "square.grid.2x2"
        case .door: return "door.left.hand.open"
        }
    }
}

struct LoadingAssembliesView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Calculating Assemblies...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
}

struct AssembliesListView: View {
    let assemblies: [Assembly]
    
    var totalCost: Double {
        assemblies.reduce(0) { $0 + $1.totalCost }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Estimated Assemblies")
                    .font(.headline)
                Spacer()
                Text("Total: $\(totalCost, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            ForEach(assemblies) { assembly in
                AssemblyCard(assembly: assembly)
            }
        }
    }
}

struct AssemblyCard: View {
    let assembly: Assembly
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(assembly.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("$\(assembly.totalCost, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            ForEach(assembly.components) { component in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(component.name)
                            .font(.caption)
                        Text("\(component.quantity, specifier: "%.1f") \(component.unit)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("$\(component.totalCost, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

#Preview {
    ResultsView(room: Room(
        dimensions: RoomDimensions(length: 12.0, width: 10.0, height: 8.0),
        surfaces: [
            Surface(type: .floor, area: 120.0),
            Surface(type: .ceiling, area: 120.0),
            Surface(type: .wall, area: 352.0)
        ],
        detectedMaterials: ["drywall", "hardwood"]
    ))
}