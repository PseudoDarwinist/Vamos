import SwiftUI

/// Category summary model for credit card statements
struct CCStatementCategorySummary: Identifiable {
    let id = UUID()
    let name: String
    let total: Decimal
    let count: Int
}

/// Category breakdown view
struct CategoryBreakdownView: View {
    let transactions: [StatementTransaction]
    
    private var categories: [CCStatementCategorySummary] {
        // Group transactions by category
        let grouped = Dictionary(grouping: transactions) { transaction in
            transaction.derived?.category ?? "Other"
        }
        
        // Calculate total for each category
        return grouped.map { category, transactions in
            let total = transactions.reduce(Decimal.zero) { result, transaction in
                if transaction.type == .debit {
                    return result + transaction.amount
                } else {
                    return result
                }
            }
            
            return CCStatementCategorySummary(
                name: category,
                total: total,
                count: transactions.count
            )
        }
        .sorted { $0.total > $1.total }
    }
    
    private var totalSpending: Decimal {
        transactions
            .filter { $0.type == .debit }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Spending by Category")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
            
            if categories.isEmpty {
                Text("No spending data available")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                ForEach(categories) { category in
                    CategoryRowView(
                        category: category,
                        totalSpending: totalSpending
                    )
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}

/// Category row view
struct CategoryRowView: View {
    let category: CCStatementCategorySummary
    let totalSpending: Decimal
    
    private var percentage: Double {
        if totalSpending == 0 { return 0 }
        return (Double(truncating: category.total as NSNumber) / Double(truncating: totalSpending as NSNumber)) * 100
    }
    
    private var categoryColor: Color {
        switch category.name {
        case "Food & Dining": return .blue
        case "Groceries": return .green
        case "Shopping": return .purple
        case "Transportation", "Fuel": return .orange
        case "Entertainment": return .pink
        case "Healthcare", "Health": return .red
        case "Utilities", "Bills": return .yellow
        case "Travel": return .mint
        case "UPI": return .cyan
        case "Education": return .indigo
        case "Business": return .brown
        case "Investment": return Color(red: 0.0, green: 0.7, blue: 0.4)
        case "Housing", "Rent": return Color(red: 0.8, green: 0.4, blue: 0.2)
        case "Insurance": return Color(red: 0.5, green: 0.5, blue: 0.8)
        case "Personal": return Color(red: 0.9, green: 0.4, blue: 0.7)
        case "Charity", "Donation": return Color(red: 0.5, green: 0.8, blue: 0.9)
        case "Other": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(category.name)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(percentage))%")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 10) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .opacity(0.2)
                            .foregroundColor(categoryColor)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(percentage) * geometry.size.width / 100, geometry.size.width), height: 8)
                            .foregroundColor(categoryColor)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
                
                // Amount
                Text(formatAmount(category.total))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(width: 80, alignment: .trailing)
            }
            
            // Transaction count
            HStack {
                Spacer()
                Text("\(category.count) transaction\(category.count == 1 ? "" : "s")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 8)
    }
    
    // Format amount
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0 // Round to whole number
        formatter.usesGroupingSeparator = false // No thousands separators
        formatter.currencySymbol = "₹"
        
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
}

struct CategoryBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CategoryBreakdownView(transactions: sampleTransactions)
                .padding()
            
            CategoryBreakdownView(transactions: [])
                .padding()
        }
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
    
    static var sampleTransactions: [StatementTransaction] {
        [
            StatementTransaction(
                date: "2023-05-10",
                description: "Swiggy Order",
                amount: 450.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "Food & Dining", merchant: "Swiggy")
            ),
            StatementTransaction(
                date: "2023-05-12",
                description: "Amazon.in Order",
                amount: 1299.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "Shopping", merchant: "Amazon")
            ),
            StatementTransaction(
                date: "2023-05-15",
                description: "Uber Ride",
                amount: 250.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "Transportation", merchant: "Uber")
            ),
            StatementTransaction(
                date: "2023-05-18",
                description: "Groceries",
                amount: 850.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "Groceries", merchant: "BigBasket")
            ),
            StatementTransaction(
                date: "2023-05-20",
                description: "UPI-BOOKMYSHOW-QWERTYUIOP",
                amount: 500.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "UPI", merchant: "BookMyShow")
            )
        ]
    }
} 