import Foundation

// MARK: - Credit Card Statement Model
struct CreditCardStatement: Codable, Hashable {
    var card: CardInfo?
    var transactions: [StatementTransaction]
    var summary: StatementSummary?
    
    enum CodingKeys: String, CodingKey {
        case card, transactions, summary
    }
    
    // Implement Hashable protocol
    func hash(into hasher: inout Hasher) {
        hasher.combine(card?.issuer)
        hasher.combine(card?.product)
        hasher.combine(card?.last4)
        hasher.combine(card?.statementPeriod?.from)
        hasher.combine(card?.statementPeriod?.to)
        hasher.combine(transactions.count)
        hasher.combine(summary?.totalSpend)
    }
    
    // Implement Equatable requirements
    static func == (lhs: CreditCardStatement, rhs: CreditCardStatement) -> Bool {
        return lhs.card?.issuer == rhs.card?.issuer &&
               lhs.card?.product == rhs.card?.product &&
               lhs.card?.last4 == rhs.card?.last4 &&
               lhs.card?.statementPeriod?.from == rhs.card?.statementPeriod?.from &&
               lhs.card?.statementPeriod?.to == rhs.card?.statementPeriod?.to &&
               lhs.transactions.count == rhs.transactions.count &&
               lhs.summary?.totalSpend == rhs.summary?.totalSpend
    }
}

struct CardInfo: Codable, Hashable {
    var issuer: String?
    var product: String?
    var last4: String?
    var statementPeriod: StatementPeriod?
    
    enum CodingKeys: String, CodingKey {
        case issuer, product, last4
        case statementPeriod = "statement_period"
    }
}

struct StatementPeriod: Codable, Hashable {
    var from: String
    var to: String
    
    enum CodingKeys: String, CodingKey {
        case from, to
    }
}

struct StatementTransaction: Codable, Identifiable {
    var date: String
    var description: String
    var amount: Decimal
    var currency: String
    var type: TransactionType
    var derived: DerivedInfo?
    
    // Create a more robust unique identifier
    var id: String {
        // Create a unique identifier by combining multiple fields with a truly unique component
        let amountString = String(describing: amount)
        let hashBase = "\(date)-\(description)-\(amountString)-\(type.rawValue)"
        let hashValue = hashBase.hashValue
        return "\(hashValue)-\(UUID().uuidString)"
    }
    
    enum CodingKeys: String, CodingKey {
        case date, description, amount, currency, type, derived
    }
}

enum TransactionType: String, Codable, Hashable {
    case credit
    case debit
}

struct DerivedInfo: Codable, Hashable {
    var category: String?
    var merchant: String?
    var isRecurring: Bool?
    var fx: ForeignExchange?
    
    init(category: String? = nil, merchant: String? = nil, isRecurring: Bool? = nil, fx: ForeignExchange? = nil) {
        self.category = category
        self.merchant = merchant
        self.isRecurring = isRecurring
        self.fx = fx
    }
    
    enum CodingKeys: String, CodingKey {
        case category, merchant
        case isRecurring = "is_recurring"
        case fx
    }
}

struct ForeignExchange: Codable, Hashable {
    var originalAmount: Decimal
    var originalCurrency: String
    
    enum CodingKeys: String, CodingKey {
        case originalAmount = "original_amount"
        case originalCurrency = "original_currency"
    }
}

struct StatementSummary: Codable, Hashable {
    var totalSpend: Decimal?
    var openingBalance: Decimal?
    var closingBalance: Decimal?
    var minPayment: Decimal?
    var dueDate: String?
    
    enum CodingKeys: String, CodingKey {
        case totalSpend = "total_spend"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance" 
        case minPayment = "min_payment"
        case dueDate = "due_date"
    }
} 