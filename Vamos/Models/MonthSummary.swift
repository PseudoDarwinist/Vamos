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
        
        // Sample category summaries
        let categorySummaries = [
            CategorySummary(
                category: .sample(name: "Food & Drink"),
                amount: 156.75,
                transactionCount: 8,
                percentOfTotal: 0.35
            ),
            CategorySummary(
                category: .sample(name: "Transportation"),
                amount: 89.50,
                transactionCount: 5,
                percentOfTotal: 0.20
            ),
            CategorySummary(
                category: .sample(name: "Groceries"),
                amount: 120.25,
                transactionCount: 3,
                percentOfTotal: 0.27
            ),
            CategorySummary(
                category: .sample(name: "Entertainment"),
                amount: 39.98,
                transactionCount: 2,
                percentOfTotal: 0.09
            ),
            CategorySummary(
                category: .sample(name: "Health"),
                amount: 45.00,
                transactionCount: 1,
                percentOfTotal: 0.10
            )
        ]
        
        return MonthSummary(
            month: firstDayOfMonth,
            totalSpent: 451.48,
            transactionCount: 19,
            categorySummaries: categorySummaries,
            narrativeSummary: "This month, you've spent most on Food & Drink. Your grocery spending is 15% lower than last month, which means your plant is growing well! 🌱"
        )
    }
}
