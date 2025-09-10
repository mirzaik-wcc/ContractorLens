
import SwiftUI

struct ScanProcessingView: View {
    @Binding var progress: Double
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Processing Scan")
                    .font(ContractorLensTheme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.horizontal, 40)
                
                Text(statusText)
                    .font(ContractorLensTheme.Typography.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .animation(.easeInOut, value: statusText)
                
                Text("Please keep the app open...")
                    .font(ContractorLensTheme.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private var statusText: String {
        if progress < 0.33 {
            return "Step 1 of 3: Computing geometry..."
        } else if progress < 0.66 {
            return "Step 2 of 3: Improving accuracy..."
        } else {
            return "Step 3 of 3: Adding color..."
        }
    }
}

#Preview {
    ScanProcessingView(progress: .constant(0.5))
}
