// File: Vamos/Services/CardStore.swift

import Foundation
import Combine

class CardStore: ObservableObject {
    static let shared = CardStore()
    
    @Published var cards: [Card] = []
    
    private let cardsKey = "savedCards"
    
    init() {
    loadCards()
    
    // Remove this block entirely to avoid adding sample cards
    /*
    // Add sample cards if none exist
    if cards.isEmpty {
        #if DEBUG
        // Only add sample cards in debug mode and if there are no cards
        cards = Card.sampleCards
        saveCards()
        #endif
    }
    */
}
    
    // MARK: - CRUD Operations
    
    func addCard(_ card: Card) {
        cards.append(card)
        saveCards()
        objectWillChange.send()
    }
    
    func updateCard(_ updatedCard: Card) {
        if let index = cards.firstIndex(where: { $0.id == updatedCard.id }) {
            cards[index] = updatedCard
            saveCards()
            objectWillChange.send()
        }
    }
    
    func deleteCard(id: UUID) {
        cards.removeAll { $0.id == id }
        saveCards()
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
        objectWillChange.send()
    }
}