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
    let category: Category
    let sourceType: SourceType
    let notes: String?
    let recurringFlag: Bool
    
    init(id: UUID = UUID(), 
         amount: Decimal, 
         date: Date, 
         merchant: String, 
         category: Category, 
         sourceType: SourceType, 
         notes: String? = nil, 
         recurringFlag: Bool = false) {
        self.id = id
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.category = category
        self.sourceType = sourceType
        self.notes = notes
        self.recurringFlag = recurringFlag
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
            )
        ]
    }
}