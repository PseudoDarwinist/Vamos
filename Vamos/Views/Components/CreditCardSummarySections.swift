import SwiftUI

// MARK: - Section Level Components

/// CategorySummaryCard - Contains pie chart + legend
struct CategorySummaryCard: View {
    let statement: CreditCardStatement
    @State private var cardVisible = false
    
    @Environment(\.colorScheme) var colorScheme
    
    private var categoryBreakdown: [CategoryPieChart.CategoryData] {
        // Group transactions by category and calculate totals
        let grouped = Dictionary(grouping: statement.transactions) { transaction in
            transaction.derived?.category ?? "Other"
        }
        
        let totalSpending = statement.transactions
            .filter { $0.type == .debit }
            .reduce(Decimal.zero) { $0 + $1.amount }
        
        // Break down complex expression into steps for better type checking
        let mappedCategories = grouped.map { category, transactions in
            let total = transactions.reduce(Decimal.zero) { result, transaction in
                if transaction.type == .debit {
                    return result + transaction.amount
                } else {
                    return result
                }
            }
            
            let percentage = totalSpending > 0 ? 
                Double(truncating: (total / totalSpending * 100) as NSNumber) : 0
            
            return CategoryPieChart.CategoryData(
                name: category,
                amount: total,
                percentage: percentage,
                color: colorForCategory(category)
            )
        }
        
        let filteredCategories = mappedCategories.filter { $0.percentage > 0 }
        let sortedCategories = filteredCategories.sorted { $0.percentage > $1.percentage }
        let categories = Array(sortedCategories.prefix(4)) // Top 4 categories
        
        return categories
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Spending by Category")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(0.2)
                .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
            
            HStack(spacing: 24) {
                // Pie Chart
                CategoryPieChart(categories: categoryBreakdown, size: 120)
                
                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categoryBreakdown) { category in
                        HStack(spacing: 8) {
                            // Color indicator
                            Circle()
                                .fill(category.color)
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
                                
                                Text("\(Int(category.percentage))%")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.adaptiveCardStroke(for: colorScheme), lineWidth: 0.75)
                .fill(Color.adaptiveCardFillPlayful(for: colorScheme))
        )
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cardVisible = true
            }
        }
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "upi":
            return Color.adaptiveAccentBlue(for: colorScheme)
        case "food & dining", "food":
            return .orange
        case "groceries":
            return .green
        case "transportation":
            return .blue
        case "entertainment":
            return .purple
        case "shopping":
            return .pink
        case "other":
            return .gray
        default:
            return Color.adaptiveAccentBlue(for: colorScheme)
        }
    }
}

/// TransactionListSection - Header + segmented control + list
struct CreditCardTransactionListSection: View {
    let statement: CreditCardStatement
    @State private var filter: TransactionFilter = .all
    @State private var sectionVisible = false
    
    @Environment(\.colorScheme) var colorScheme
    
    enum TransactionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case debit = "Debits"
        case credit = "Credits"
        
        var id: String { self.rawValue }
        
        var label: String { self.rawValue }
    }
    
    private var filteredTransactions: [StatementTransaction] {
        switch filter {
        case .all:
            return statement.transactions.sorted { $0.date > $1.date }
        case .debit:
            return statement.transactions
                .filter { $0.type == .debit }
                .sorted { $0.date > $1.date }
        case .credit:
            return statement.transactions
                .filter { $0.type == .credit }
                .sorted { $0.date > $1.date }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Filter
            HStack {
                Text("Transactions")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(0.2)
                    .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
                
                Spacer()
                
                Picker("Filter", selection: $filter) {
                    ForEach(TransactionFilter.allCases) { filter in
                        Text(filter.label)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            // Transaction List
            LazyVStack(spacing: 16) {
                ForEach(filteredTransactions) { transaction in
                    CreditCardTransactionRow(transaction: transaction)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.adaptiveCardStroke(for: colorScheme), lineWidth: 0.75)
                .fill(Color.adaptiveCardFillPlayful(for: colorScheme))
        )
        .opacity(sectionVisible ? 1 : 0)
        .offset(y: sectionVisible ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                sectionVisible = true
            }
        }
    }
}

// MARK: - Preview Support

extension CreditCardStatement {
    static var mock: CreditCardStatement {
        let cardInfo = CardInfo(
            issuer: "HDFC Bank",
            product: "Regalia",
            last4: "1234",
            statementPeriod: StatementPeriod(from: "2024-04-01", to: "2024-04-30")
        )
        
        let summary = StatementSummary(
            totalSpend: 1400.0,
            openingBalance: 10000.0,
            closingBalance: 11400.0,
            minPayment: 1400.0,
            dueDate: "2024-05-15"
        )
        
        let transactions = [
            StatementTransaction(
                date: "2024-05-02",
                description: "SWIGGY Order #12345",
                amount: 180.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "Food & Dining", merchant: "Swiggy")
            ),
            StatementTransaction(
                date: "2024-05-01",
                description: "UPI-INSTMART-ORDER",
                amount: 720.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "UPI", merchant: "INSTMART")
            ),
            StatementTransaction(
                date: "2024-05-01",
                description: "UPI transfer RATI MEHRA",
                amount: 500.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "UPI", merchant: "RATI MEHRA")
            )
        ]
        
        return CreditCardStatement(
            card: cardInfo,
            transactions: transactions,
            summary: summary
        )
    }
} 