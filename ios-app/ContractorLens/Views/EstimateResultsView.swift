import SwiftUI

struct EstimateResultsView: View {
    @StateObject private var viewModel = EstimateViewModel()
    let scanResult: RoomScanResult
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingChat = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if let estimate = viewModel.currentEstimate {
                    estimateContentView(estimate)
                } else if viewModel.hasError {
                    errorView
                }
            }
            .navigationTitle("Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if viewModel.currentEstimate == nil {
                    // In a real app, this would trigger a network request
                    // For now, it uses a mock data generator that needs to be updated
                    // viewModel.generateEstimateWithGeminiAnalysis(from: scanResult)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("Analyzing Scan & Generating V2 Estimate...")
                .font(.headline)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Unable to Generate Estimate")
                .font(.title2)
            Button("Retry") { /* viewModel.retry(with: scanResult) */ }
        }
    }
    
    private func estimateContentView(_ estimate: Estimate) -> some View {
        List {
            Section {
                totalCostHeaderView(estimate)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(estimate.csiDivisions) { division in
                Section(header: Text("\(division.csiCode) - \(division.divisionName)").font(.headline)) {
                    ForEach(division.lineItems) { item in
                        LineItemRowV2(item: item)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func totalCostHeaderView(_ estimate: Estimate) -> some View {
        VStack(spacing: 16) {
            VStack {
                Text("Total Estimated Cost")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(estimate.grandTotal, format: .currency(code: "USD"))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
            }
            
            Text("Generated: \(estimate.metadata.calculationDate)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct LineItemRowV2: View {
    let item: LineItem
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.description)
                        .fontWeight(.medium)
                    Text("\(item.quantity.formatted()) \(item.unit) @ \(item.unitCost, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(item.totalCost, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    if let manufacturer = item.manufacturer {
                        detailRow(label: "Manufacturer", value: "\(manufacturer) \(item.modelNumber ?? "")")
                    }
                    if let specs = item.specifications {
                        detailRow(label: "Size", value: specs.sizeDimensions ?? "N/A")
                    }
                    if let labor = item.laborDetails {
                        detailRow(label: "Labor Breakdown", value: "\(labor.totalHours.formatted()) hrs (\(labor.baseHours.formatted()) base + adjustments)")
                    }
                    if let quantity = item.quantityDetails {
                        detailRow(label: "Material Quantity", value: "\(quantity.totalQuantity.formatted()) total (\(quantity.baseQuantity.formatted()) base + waste)")
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
