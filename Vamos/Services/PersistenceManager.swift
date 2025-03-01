import Foundation
import Combine

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let transactionsKey = "savedTransactions"
    
    // Save transactions to UserDefaults
    func saveTransactions(_ transactions: [Transaction]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(transactions)
            UserDefaults.standard.set(data, forKey: transactionsKey)
            print("📝 Successfully saved \(transactions.count) transactions")
        } catch {
            print("❌ Failed to save transactions: \(error.localizedDescription)")
        }
    }
    
    // Load transactions from UserDefaults
    func loadTransactions() -> [Transaction] {
        guard let data = UserDefaults.standard.data(forKey: transactionsKey) else {
            print("📝 No saved transactions found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let transactions = try decoder.decode([Transaction].self, from: data)
            print("📝 Successfully loaded \(transactions.count) transactions")
            return transactions
        } catch {
            print("❌ Failed to load transactions: \(error.localizedDescription)")
            return []
        }
    }
    
    // Clear all saved transactions (for testing/debugging)
    func clearAllTransactions() {
        UserDefaults.standard.removeObject(forKey: transactionsKey)
        print("🧹 Cleared all saved transactions")
    }
}