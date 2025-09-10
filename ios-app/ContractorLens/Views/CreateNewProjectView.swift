
import SwiftUI

struct CreateNewProjectView: View {
    @Binding var isPresented: Bool
    @State private var projectName: String = ""
    
    // Action to be performed when project is created
    var onCreate: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Name Your Project")
                    .font(ContractorLensTheme.Typography.title1)
                    .fontWeight(.bold)
                
                TextField("e.g., Kitchen Remodel", text: $projectName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitle("Create New Project", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Create") {
                    onCreate(projectName)
                    isPresented = false
                }
                .disabled(projectName.isEmpty)
            )
        }
    }
}

#Preview {
    CreateNewProjectView(isPresented: .constant(true)) { projectName in
        print("Project created: \(projectName)")
    }
}
