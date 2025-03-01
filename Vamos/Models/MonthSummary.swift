import Foundation

struct CategorySummary: Identifiable, Codable {
    let id: UUID
    let category: Category
    let amount: Decimal
    let transactionCount: Int
    let percentOfTotal: Double
    
    init(id: UUID = UUID(), category: Category, amount: Decimal, transactionCount: Int, percentOfTotal: Double) {
        self.id = id
        self.category = category
        self.amount = amount
        self.transactionCount = transactionCount
        self.percentOfTotal = percentOfTotal
    }
}

struct MonthSummary: Identifiable, Codable {
    let id: UUID
    let month: Date // First day of month
    let totalSpent: Decimal
    let transactionCount: Int
    let categorySummaries: [CategorySummary]
    var narrativeSummary: String // Changed from 'let' to 'var'
    
    init(id: UUID = UUID(),
         month: Date,
         totalSpent: Decimal,
         transactionCount: Int,
         categorySummaries: [CategorySummary],
         narrativeSummary: String) {
        self.id = id
        self.month = month
        self.totalSpent = totalSpent
        self.transactionCount = transactionCount
        self.categorySummaries = categorySummaries
        self.narrativeSummary = narrativeSummary
    }
    
    // Calculate month name (e.g., "February")
    var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: month)
    }
    
    // Calculate year (e.g., "2025")
    var yearString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        return dateFormatter.string(from: month)
    }
}

// MARK: - Sample Data
extension MonthSummary {
    static var sample: MonthSummary {
        // Get current month's first day
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let firstDayOfMonth = calendar.date(from: components)!
        
        // Empty category summaries
        let categorySummaries: [CategorySummary] = []
        
        return MonthSummary(
            month: firstDayOfMonth,
            totalSpent: 0,
            transactionCount: 0,
            categorySummaries: categorySummaries,
            narrativeSummary: "Add your first transaction to see insights about your spending habits."
        )
    }
}
