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
                    viewModel.generateEstimateWithGeminiAnalysis(from: scanResult)
                }
            }
            .sheet(isPresented: $showingChat) {
                if let estimate = viewModel.currentEstimate {
                    ChatView(viewModel: ChatViewModel(estimate: estimate)) { updatedEstimate in
                        // When the chat view is dismissed, update the estimate
                        self.viewModel.currentEstimate = updatedEstimate
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("Analyzing Scan & Generating Estimate...")
                .font(ContractorLensTheme.Typography.headline)
                .foregroundColor(ContractorLensTheme.Colors.textSecondary)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Unable to Generate Estimate")
                .font(ContractorLensTheme.Typography.title2)
            Button("Retry") { viewModel.retry(with: scanResult) }
                .buttonStyle(PrimaryButtonStyle())
        }
    }
    
    private func estimateContentView(_ estimate: Estimate) -> some View {
        List {
            Section {
                totalCostHeaderView(estimate)
            } 
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(estimate.sections) { section in
                Section(header: Text(section.trade).font(ContractorLensTheme.Typography.headline)) {
                    ForEach(section.lineItems) { item in
                        lineItemRow(item)
                    }
                }
            }
            
            Section {
                Button(action: { showingChat = true }) {
                    HStack {
                        Image(systemName: "message.and.waveform.fill")
                        Text("Modify with AI Assistant")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))

        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func totalCostHeaderView(_ estimate: Estimate) -> some View {
        VStack(spacing: 16) {
            Text(estimate.projectName)
                .font(ContractorLensTheme.Typography.largeTitle)
                .fontWeight(.bold)

            VStack {
                Text("Total Estimated Cost")
                    .font(ContractorLensTheme.Typography.subheadline)
                    .foregroundColor(.secondary)
                Text(estimate.totalCost, format: .currency(code: "USD"))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(ContractorLensTheme.Colors.primary)
            }
            
            Text("Generated: \(estimate.generatedAt.formatted(date: .long, time: .shortened))")
                .font(ContractorLensTheme.Typography.caption1)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(ContractorLensTheme.Colors.surface)
    }
    
    private func lineItemRow(_ item: LineItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let supplier = item.supplier {
                Image(supplier.logoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(item.quantity.formatted()) \(item.unit) @ \(item.unitCost, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(item.totalCost, format: .currency(code: "USD"))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
}

struct EstimateResultsView_Previews: PreviewProvider {
    static var previews: some View {
        EstimateResultsView(
            scanResult: RoomScanResult(
                roomType: .kitchen,
                dimensions: RoomDimensions(length: 12, width: 10, height: 9),
                surfaces: [],
                arFrames: [],
                metadata: ScanMetadata()
            )
        )
    }
}