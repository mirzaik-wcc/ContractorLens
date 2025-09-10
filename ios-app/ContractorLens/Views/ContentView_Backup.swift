import SwiftUI

// Backup of original ContentView
struct ContentView_Original: View {
    @StateObject private var arService = ARService()
    @State private var showingScanner = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: ContractorLensTheme.Spacing.xl) {
                    HeaderView()
                    
                    ScanButtonView(showingScanner: $showingScanner)
                    
                    if let room = arService.roomData {
                        RecentScanView(room: room)
                    }
                    
                    FeaturesOverviewView()
                    
                    Spacer(minLength: ContractorLensTheme.Spacing.xl)
                }
                .padding(ContractorLensTheme.Spacing.md)
            }
            .background(ContractorLensTheme.Colors.background)
            .navigationTitle("ContractorLens")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingScanner) {
                ScanningView()
            }
        }
        .environmentObject(arService)
        .contractorLensStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ContractorLens main screen")
    }
}