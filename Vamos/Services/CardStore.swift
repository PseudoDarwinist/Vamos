// File: Vamos/Services/CardStore.swift

import Foundation
import Combine

class CardStore: ObservableObject {
    static let shared = CardStore()
    
    @Published var cards: [Card] = []
    
    private let cardsKey = "savedCards"
    
    init() {
        print("🔍 CardStore init - Starting initialization")
        loadCards()
        print("🔍 CardStore init - After loadCards, cards count: \(cards.count)")
        
        // Force a UI update after initialization
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - CRUD Operations
    
    func addCard(_ card: Card) {
        cards.append(card)
        saveCards()
        // Force a UI update
        objectWillChange.send()
    }
    
    func updateCard(_ updatedCard: Card) {
        if let index = cards.firstIndex(where: { $0.id == updatedCard.id }) {
            cards[index] = updatedCard
            saveCards()
            // Force a UI update
            objectWillChange.send()
        }
    }
    
    func deleteCard(id: UUID) {
        cards.removeAll { $0.id == id }
        saveCards()
        // Force a UI update
        objectWillChange.send()
    }
    
    func getCard(id: UUID) -> Card? {
        return cards.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    private func saveCards() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cards)
            UserDefaults.standard.set(data, forKey: cardsKey)
            print("📝 Successfully saved \(cards.count) cards")
        } catch {
            print("❌ Failed to save cards: \(error.localizedDescription)")
        }
    }
    
    private func loadCards() {
        guard let data = UserDefaults.standard.data(forKey: cardsKey) else {
            print("📝 No saved cards found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            cards = try decoder.decode([Card].self, from: data)
            print("📝 Successfully loaded \(cards.count) cards")
        } catch {
            print("❌ Failed to load cards: \(error.localizedDescription)")
        }
    }
    
    // Clear all saved cards (for testing/debugging)
    func clearAllCards() {
        cards.removeAll()
        UserDefaults.standard.removeObject(forKey: cardsKey)
        print("🧹 Cleared all saved cards")
        // Force a UI update
        objectWillChange.send()
    }
}