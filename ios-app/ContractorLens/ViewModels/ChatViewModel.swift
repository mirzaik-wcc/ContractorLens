
import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false
    
    // The estimate that can be modified by the chat
    @Published var estimate: Estimate
    
    private var cancellables = Set<AnyCancellable>()

    init(estimate: Estimate) {
        self.estimate = estimate
        // Add a welcome message
        self.messages.append(ChatMessage(text: "Hello! How can I help you modify this estimate?", isFromUser: false))
    }
    
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(text: text, isFromUser: true)
        messages.append(userMessage)
        
        isTyping = true
        
        // Simulate a backend call and a mocked response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isTyping = false
            self.processModificationRequest(text)
        }
    }
    
    private func processModificationRequest(_ text: String) {
        let response: String
        let lowercasedText = text.lowercased()
        
        // Mocked understanding of user requests
        if lowercasedText.contains("paint") && lowercasedText.contains("blue") {
            response = "Of course. I've updated the paint to a premium blue shade. This will adjust the material cost slightly."
            // Simulate changing the estimate
            if let paintSectionIndex = estimate.sections.firstIndex(where: { $0.trade == "Painting" }) {
                if let paintItemIndex = estimate.sections[paintSectionIndex].lineItems.firstIndex(where: { $0.description.contains("Paint walls") }) {
                    var updatedItem = estimate.sections[paintSectionIndex].lineItems[paintItemIndex]
                    updatedItem.unitCost = 1.50 // Increase unit cost for premium paint
                    updatedItem.totalCost = updatedItem.unitCost * updatedItem.quantity
                    estimate.sections[paintSectionIndex].lineItems[paintItemIndex] = updatedItem
                    recalculateTotalCost()
                }
            }
        } else if lowercasedText.contains("flooring") {
            response = "I can certainly change the flooring. What type of flooring would you like instead?"
        } else if lowercasedText.contains("add an outlet") {
            response = "Okay, I've added a new outlet to the Electrical section."
            if let electricalSectionIndex = estimate.sections.firstIndex(where: { $0.trade == "Electrical" }) {
                let newItem = LineItem(id: UUID(), description: "Add 1 new standard outlet", quantity: 1, unit: "each", unitCost: 125.00, totalCost: 125.00, supplier: .homeDepot)
                estimate.sections[electricalSectionIndex].lineItems.append(newItem)
                recalculateTotalCost()
            }
        } else {
            response = "I'm sorry, I can only handle simple requests like changing paint color or adding outlets right now. How else can I help?"
        }
        
        messages.append(ChatMessage(text: response, isFromUser: false))
    }
    
    private func recalculateTotalCost() {
        let newTotal = estimate.sections.reduce(0) { $0 + $1.sectionTotal }
        estimate = Estimate(id: estimate.id, projectName: estimate.projectName, totalCost: newTotal, generatedAt: estimate.generatedAt, sections: estimate.sections)
    }
}
