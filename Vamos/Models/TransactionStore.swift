import Foundation
import Combine

// Singleton store to hold all transactions across the app
class TransactionStore: ObservableObject {
    static let shared = TransactionStore()
    
    @Published var transactions: [Transaction] = []
    
    private init() {
        // Load saved transactions when the store is initialized
        loadSavedTransactions()
    }
    
    // Load transactions from persistence
    private func loadSavedTransactions() {
        self.transactions = PersistenceManager.shared.loadTransactions()
    }
    
    // Save current transactions to persistence
    private func saveTransactions() {
        PersistenceManager.shared.saveTransactions(transactions)
    }
    
    // Add a new transaction to the store
    func addTransaction(_ transaction: Transaction) {
        print("🔄 ADDING TRANSACTION:")
        print("  - Merchant: \(transaction.merchant)")
        print("  - Aggregator: \(transaction.aggregator ?? "None")")
        print("  - Initial Category: \(transaction.category.name)")
        
        // Auto-categorize the transaction based on merchant name if not already categorized
        var newTransaction = transaction
        
        if transaction.category.name == "Miscellaneous" {
            let merchantName = transaction.aggregator ?? transaction.merchant
            let category = categoryForMerchant(merchantName)
            print("  - Miscellaneous detected, recategorizing")
            print("  - Merchant: \(transaction.merchant)")
            print("  - Aggregator: \(transaction.aggregator ?? "None")")
            print("  - New Category: \(category.name)")
            
            newTransaction = Transaction(
                id: transaction.id,
                amount: transaction.amount,
                date: transaction.date,
                merchant: transaction.merchant,
                aggregator: transaction.aggregator,
                category: category,
                sourceType: transaction.sourceType,
                notes: transaction.notes,
                recurringFlag: transaction.recurringFlag
            )
        } else {
            print("  - Keeping original category: \(transaction.category.name)")
        }
        
        transactions.append(newTransaction)
        // Save changes to persistence
        saveTransactions()
        // Notify observers
        objectWillChange.send()
        
        print("🔄 TRANSACTION ADDED with final category: \(newTransaction.category.name)")
    }
    
    // Clear all transactions
    func clearAllTransactions() {
        transactions.removeAll()
        PersistenceManager.shared.clearAllTransactions()
        objectWillChange.send()
    }
    
    // Group transactions by category
    func groupByCategory() -> [String: [Transaction]] {
        return Dictionary(grouping: transactions) { transaction in
            transaction.category.name
        }
    }
    
    // Get category totals for UI display
    func getCategoryTotals() -> [CategoryTotal] {
        let grouped = groupByCategory()
        
        var categoryTotals: [CategoryTotal] = []
        
        for (_, categoryTransactions) in grouped {
            let total = categoryTransactions.reduce(0) { $0 + $1.amount }
            
            // Get the category from the first transaction
            if let firstTransaction = categoryTransactions.first {
                let category = firstTransaction.category
                
                categoryTotals.append(CategoryTotal(
                    category: category,
                    amount: total,
                    count: categoryTransactions.count
                ))
            }
        }
        
        // Sort by amount (descending)
        return categoryTotals.sorted(by: { $0.amount > $1.amount })
    }
    
    // Group transactions by merchant within a category
    // This is a key function to support the new hierarchy
    func groupByMerchantInCategory(categoryName: String) -> [(merchant: String, total: Decimal, count: Int)] {
        // First filter transactions by category
        let categoryTransactions = transactions.filter { $0.category.name == categoryName }
        
        // Group transactions by aggregator (or merchant if no aggregator)
        var merchantGroups: [String: [Transaction]] = [:]
        
        for transaction in categoryTransactions {
            // Use aggregator as the grouping key if available, otherwise use merchant
            let groupKey = transaction.aggregator ?? transaction.merchant
            if merchantGroups[groupKey] == nil {
                merchantGroups[groupKey] = []
            }
            merchantGroups[groupKey]?.append(transaction)
        }
        
        // Calculate totals for each merchant group
        return merchantGroups.map { (merchant, transactions) in
            let total = transactions.reduce(0) { $0 + $1.amount }
            return (merchant: merchant, total: total, count: transactions.count)
        }.sorted { $0.total > $1.total }
    }
    
    // Get merchant totals within a category
    func getMerchantTotalsInCategory(categoryName: String) -> [MerchantTotal] {
        let merchantGroups = groupByMerchantInCategory(categoryName: categoryName)
        
        return merchantGroups.map { merchant, total, count in
            MerchantTotal(
                merchantName: merchant,
                icon: iconForMerchant(merchant),
                amount: total,
                count: count
            )
        }
    }
    
    // Helper to determine icon for merchant
    public func iconForMerchant(_ merchantName: String) -> String {
        let merchant = merchantName.lowercased()
        
        if merchant.contains("swiggy") {
            return "takeoutbag.and.cup.and.straw.fill"
        } else if merchant.contains("zomato") {
            return "fork.knife"
        } else if merchant.contains("amazon") {
            return "cart.fill"
        } else if merchant.contains("flipkart") {
            return "bag.fill"
        } else if merchant.contains("uber") || merchant.contains("ola") || merchant.contains("taxi") {
            return "car.fill"
        } else if merchant.contains("petrol") || merchant.contains("gas") || merchant.contains("fuel") {
            return "fuelpump.fill"
        } else if merchant.contains("netflix") || merchant.contains("prime") || merchant.contains("hotstar") {
            return "play.tv.fill"
        } else if merchant.contains("grocery") || merchant.contains("market") {
            return "basket.fill"
        } else if merchant.contains("pharmacy") || merchant.contains("medical") {
            return "cross.case.fill"
        } else if merchant.contains("gym") || merchant.contains("fitness") {
            return "figure.walk"
        } else if merchant.contains("salon") || merchant.contains("spa") {
            return "scissors"
        } else if merchant.contains("education") || merchant.contains("school") || merchant.contains("college") {
            return "book.fill"
        } else if merchant.contains("bill") || merchant.contains("utility") {
            return "doc.text.fill"
        } else if merchant.contains("food") || merchant.contains("restaurant") || merchant.contains("cafe") || 
                  merchant.contains("kfc") || merchant.contains("nazeer") || merchant.contains("starbucks") {
            return "takeoutbag.and.cup.and.straw.fill"
        } else if merchant.contains("myntra") || merchant.contains("ajio") || merchant.contains("shopping") {
            return "cart.fill"
        } else if merchant.contains("metro") || merchant.contains("train") || merchant.contains("bus") || 
                  merchant.contains("rapido") {
            return "bus.fill"
        } else if merchant.contains("disney") || merchant.contains("hbo") || merchant.contains("movie") || 
                  merchant.contains("entertainment") || merchant.contains("book") {
            return "play.tv.fill"
        } else if merchant.contains("health") || merchant.contains("hospital") || merchant.contains("doctor") || 
                  merchant.contains("medicine") {
            return "heart.fill"
        } else if merchant.contains("course") || merchant.contains("class") {
            return "book.fill"
        } else if merchant.contains("supermarket") || merchant.contains("store") {
            return "cart.fill.badge.plus"
        } else if merchant.contains("electricity") || merchant.contains("water") || merchant.contains("internet") || 
                  merchant.contains("broadband") || merchant.contains("phone") || merchant.contains("mobile") {
            return "bolt.fill"
        } else if merchant.contains("hotel") || merchant.contains("flight") || merchant.contains("travel") || 
                  merchant.contains("booking") || merchant.contains("trip") || merchant.contains("vacation") {
            return "airplane"
        } else if merchant.contains("bank") || merchant.contains("finance") || merchant.contains("insurance") || 
                  merchant.contains("investment") || merchant.contains("loan") || merchant.contains("credit") {
            return "banknote"
        } else {
            return "tag.fill"
        }
    }
    
    // Map merchant name to category
    func categoryForMerchant(_ merchantName: String) -> Category {
        let merchant = merchantName.lowercased()
        
        // Check for food delivery aggregators first
        if merchant.contains("swiggy") || merchant.contains("zomato") {
            return Category.sample(name: "Food & Dining")
        }
        // Then check for Amazon specifically before other shopping platforms
        else if merchant.contains("amazon") {
            return Category.sample(name: "Shopping")
        }
        // Other Food & Dining merchants
        else if merchant.contains("food") || merchant.contains("restaurant") || 
           merchant.contains("cafe") || merchant.contains("kfc") || 
           merchant.contains("nazeer") || merchant.contains("starbucks") {
            return Category.sample(name: "Food & Dining")
        } else if merchant.contains("flipkart") || 
                  merchant.contains("myntra") || merchant.contains("ajio") || 
                  merchant.contains("shopping") {
            return Category.sample(name: "Shopping")
        } else if merchant.contains("uber") || merchant.contains("ola") || 
                  merchant.contains("taxi") || merchant.contains("petrol") || 
                  merchant.contains("gas") || merchant.contains("fuel") || 
                  merchant.contains("metro") || merchant.contains("train") || 
                  merchant.contains("bus") || merchant.contains("rapido") {
            return Category.sample(name: "Transportation")
        } else if merchant.contains("netflix") || merchant.contains("prime") || 
                  merchant.contains("disney") || merchant.contains("hbo") || 
                  merchant.contains("movie") || merchant.contains("entertainment") || 
                  merchant.contains("book") {
            return Category.sample(name: "Entertainment")
        } else if merchant.contains("gym") || merchant.contains("fitness") || 
                  merchant.contains("health") || merchant.contains("pharmacy") || 
                  merchant.contains("hospital") || merchant.contains("doctor") || 
                  merchant.contains("medicine") {
            return Category.sample(name: "Health & Wellness")
        } else if merchant.contains("education") || merchant.contains("school") || 
                  merchant.contains("college") || merchant.contains("university") || 
                  merchant.contains("course") || merchant.contains("class") {
            return Category.sample(name: "Education")
        } else if merchant.contains("grocery") || merchant.contains("supermarket") || 
                  merchant.contains("market") || merchant.contains("store") {
            return Category.sample(name: "Groceries")
        } else if merchant.contains("utility") || merchant.contains("electricity") || 
                  merchant.contains("water") || merchant.contains("gas") || 
                  merchant.contains("internet") || merchant.contains("broadband") || 
                  merchant.contains("phone") || merchant.contains("mobile") {
            return Category.sample(name: "Utilities")
        } else if merchant.contains("hotel") || merchant.contains("flight") || 
                  merchant.contains("travel") || merchant.contains("booking") || 
                  merchant.contains("trip") || merchant.contains("vacation") {
            return Category.sample(name: "Travel & Accommodation")
        } else if merchant.contains("bank") || merchant.contains("finance") || 
                  merchant.contains("insurance") || merchant.contains("investment") || 
                  merchant.contains("loan") || merchant.contains("credit") {
            return Category.sample(name: "Finance & Banking")
        } else {
            return Category.sample(name: "Miscellaneous")
        }
    }
    
    // Get transactions for a specific category
    func transactionsForCategory(_ categoryName: String) -> [Transaction] {
        return transactions.filter { $0.category.name == categoryName }
    }
    
    // Method to get transactions for a specific merchant in a specific category
    // This is updated to handle the aggregator field
    func transactionsForMerchantInCategory(merchant: String, categoryName: String) -> [Transaction] {
        return transactions.filter { transaction in
            // First check if the transaction belongs to the specified category
            guard transaction.category.name == categoryName else {
                return false
            }
            
            // For aggregators like Swiggy, check if this transaction has that aggregator
            if isKnownAggregator(merchant) {
                return transaction.aggregator == merchant
            }
            
            // For regular merchants, check if this transaction is not from an aggregator
            // and the merchant name matches
            return transaction.aggregator == nil && 
                  transaction.merchant.lowercased().contains(merchant.lowercased())
        }
    }
    
    // Helper function to check if a merchant is a known aggregator
    func isKnownAggregator(_ merchant: String) -> Bool {
        let knownAggregators = ["Swiggy", "Zomato", "Amazon", "Flipkart", "Uber", "Ola"]
        return knownAggregators.contains(merchant)
    }
    
    // Get total spending for a specific category
    func totalForCategory(_ categoryName: String) -> Decimal {
        return transactions
            .filter { $0.category.name == categoryName }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Get all unique categories that have transactions
    func categoriesWithTransactions() -> [Category] {
        var uniqueCategories: [Category] = []
        let allCategories = transactions.map { $0.category }
        
        for category in allCategories {
            if !uniqueCategories.contains(where: { $0.name == category.name }) {
                uniqueCategories.append(category)
            }
        }
        
        return uniqueCategories.sorted(by: { $0.name < $1.name })
    }
}

// Model for category total data
struct CategoryTotal: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let count: Int
}

// Model for merchant total data
struct MerchantTotal: Identifiable {
    let id = UUID()
    let merchantName: String
    let icon: String
    let amount: Decimal
    let count: Int
}