import Foundation
import SwiftUI

enum SourceType: String, Codable {
    case manual = "manual"
    case scanned = "scanned"
    case digital = "digital"
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    let amount: Decimal
    let date: Date
    let merchant: String
    let aggregator: String? // New field to store the aggregator (Swiggy, Zomato, etc.)
    let category: Category
    let sourceType: SourceType
    let notes: String?
    let recurringFlag: Bool
    
    init(id: UUID = UUID(), 
         amount: Decimal, 
         date: Date, 
         merchant: String, 
         aggregator: String? = nil, // Added aggregator parameter with default nil
         category: Category, 
         sourceType: SourceType, 
         notes: String? = nil, 
         recurringFlag: Bool = false) {
        self.id = id
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.aggregator = aggregator
        self.category = category
        self.sourceType = sourceType
        self.notes = notes
        self.recurringFlag = recurringFlag
    }
    
    // Helper method to get the display merchant
    func displayMerchant() -> String {
        // If there's an aggregator, we should show the actual merchant
        // Otherwise, just show the merchant as normal
        return merchant
    }
    
    // Helper method to get the effective "parent" for grouping
    // This will be the aggregator if available, or merchant if not
    func groupingMerchant() -> String {
        return aggregator ?? merchant
    }
}

// MARK: - Sample Data
extension Transaction {
    static var sampleTransactions: [Transaction] {
        [
            Transaction(
                amount: 12.99,
                date: Date().addingTimeInterval(-86400), // yesterday
                merchant: "Starbucks",
                category: .sample(name: "Food & Drink"),
                sourceType: .manual
            ),
            Transaction(
                amount: 24.50,
                date: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                merchant: "Uber",
                category: .sample(name: "Transportation"),
                sourceType: .digital
            ),
            Transaction(
                amount: 85.75,
                date: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                merchant: "Whole Foods",
                category: .sample(name: "Groceries"),
                sourceType: .scanned,
                notes: "Weekly groceries"
            ),
            Transaction(
                amount: 9.99,
                date: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                merchant: "Netflix",
                category: .sample(name: "Entertainment"),
                sourceType: .digital,
                recurringFlag: true
            ),
            Transaction(
                amount: 45.00,
                date: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                merchant: "Gym Membership",
                category: .sample(name: "Health"),
                sourceType: .digital,
                recurringFlag: true
            ),
            // Add sample transactions with aggregators
            Transaction(
                amount: 32.50,
                date: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                merchant: "KFC",
                aggregator: "Swiggy",
                category: .sample(name: "Food & Dining"),
                sourceType: .digital
            ),
            Transaction(
                amount: 28.75,
                date: Date().addingTimeInterval(-86400 * 4), // 4 days ago
                merchant: "Domino's Pizza",
                aggregator: "Zomato",
                category: .sample(name: "Food & Dining"),
                sourceType: .digital
            )
        ]
    }
}