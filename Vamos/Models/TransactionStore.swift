import Foundation
import Combine

// Singleton store to hold all transactions across the app
class TransactionStore: ObservableObject {
    static let shared = TransactionStore()
    
    @Published var transactions: [Transaction] = Transaction.sampleTransactions
    
    // Add a new transaction to the store
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        // Notify observers
        objectWillChange.send()
    }
    
    // Group transactions by merchant
    func groupByMerchant() -> [String: [Transaction]] {
        let groupedDict = Dictionary(grouping: transactions) { transaction in
            let merchant = transaction.merchant.lowercased()
            
            // Map known merchants to standardized names
            if merchant.contains("amazon") {
                return "Amazon"
            } else if merchant.contains("swiggy") || merchant.contains("food") || merchant.contains("kfc") {
                return "Swiggy"
            } else if merchant.contains("uber") {
                return "Uber"
            } else {
                return "Other"
            }
        }
        return groupedDict
    }
    
    // Get merchant totals for UI display
    func getMerchantTotals() -> [MerchantTotal] {
        let grouped = groupByMerchant()
        
        var merchantTotals: [MerchantTotal] = []
        
        // Standard merchants in preferred order
        let standardMerchants = ["Swiggy", "Amazon", "Uber", "Other"]
        
        for merchant in standardMerchants {
            let transactions = grouped[merchant] ?? []
            let total = transactions.reduce(0) { $0 + $1.amount }
            
            // Skip if no transactions for this merchant
            if transactions.isEmpty && merchant != "Other" {
                continue
            }
            
            // Assign appropriate icon based on merchant
            let icon: String
            switch merchant {
            case "Swiggy":
                icon = "takeoutbag.and.cup.and.straw.fill"
            case "Amazon":
                icon = "cart.fill"
            case "Uber":
                icon = "car.fill"
            default:
                icon = "briefcase.fill"
            }
            
            merchantTotals.append(MerchantTotal(
                merchantName: merchant,
                icon: icon,
                amount: Double(truncating: total as NSNumber),
                count: transactions.count
            ))
        }
        
        return merchantTotals
    }
}

// Model for merchant total data
struct MerchantTotal: Identifiable {
    let id = UUID()
    let merchantName: String
    let icon: String
    let amount: Double
    let count: Int
}