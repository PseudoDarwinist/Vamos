import SwiftUI

// MARK: - Section Level Components

/// CategorySummaryCard - Pie chart + legend showing spending breakdown by category (Performance Optimized)
struct CategorySummaryCard: View {
    let statement: CreditCardStatement
    @State private var cardVisible = false
    @State private var categoryBreakdown: [CategoryPieChart.CategoryData] = []
    @State private var isLoading = true
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Spending by Category")
                .font(.sectionHeader)
                .tracking(0.2)
                .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
            
            if isLoading {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.vertical, 60)
                    Spacer()
                }
            } else {
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
                                        .font(.categoryLabel)
                                        .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
                                    
                                    Text("\(Int(category.percentage))%")
                                        .font(.percentage)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
            computeCategoryBreakdown()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cardVisible = true
            }
        }
    }
    
    // MARK: - Performance Optimized Methods
    
    private func computeCategoryBreakdown() {
        // Perform expensive computation on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Group transactions by category
            let grouped = Dictionary(grouping: self.statement.transactions) { transaction in
                transaction.derived?.category ?? "Other"
            }
            
            // Step 2: Calculate total spending
            let debitTransactions = self.statement.transactions.filter { $0.type == .debit }
            let totalSpending = debitTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            
            // Step 3: Process categories one by one
            var categoryData: [CategoryPieChart.CategoryData] = []
            
            for (category, transactions) in grouped {
                // Calculate total for this category
                let debitTransactionsForCategory = transactions.filter { $0.type == .debit }
                let categoryTotal = debitTransactionsForCategory.reduce(Decimal.zero) { $0 + $1.amount }
                
                // Calculate percentage
                let percentage: Double
                if totalSpending > 0 {
                    let ratio = categoryTotal / totalSpending * 100
                    percentage = Double(truncating: ratio as NSNumber)
                } else {
                    percentage = 0
                }
                
                // Only include categories with spending
                if percentage > 0 {
                    let data = CategoryPieChart.CategoryData(
                        name: category,
                        amount: categoryTotal,
                        percentage: percentage,
                        color: self.colorForCategory(category)
                    )
                    categoryData.append(data)
                }
            }
            
            // Step 4: Sort by percentage descending
            let sortedCategories = categoryData.sorted { $0.percentage > $1.percentage }
            
            // Step 5: Update UI on main thread
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.categoryBreakdown = sortedCategories
                    self.isLoading = false
                }
            }
        }
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "upi":
            return .blue
        case "fuel":
            return .orange
        case "food & dining", "food":
            return .red
        case "groceries":
            return .green
        case "transportation":
            return .purple
        case "entertainment":
            return .pink
        case "shopping":
            return .indigo
        case "other":
            return .gray
        default:
            return .cyan
        }
    }
}

/// TransactionListSection - Header + segmented control + list (Performance Optimized)
struct CreditCardTransactionListSection: View {
    let statement: CreditCardStatement
    @State private var filter: TransactionFilter = .all
    @State private var sectionVisible = false
    @State private var filteredTransactions: [StatementTransaction] = []
    @State private var displayedTransactions: [StatementTransaction] = []
    @State private var itemsToShow = 5 // Start with fewer items for better performance
    private let itemsPerPage = 5 // Smaller batches for smoother loading
    
    @Environment(\.colorScheme) var colorScheme
    
    enum TransactionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case debit = "Debits"
        case credit = "Credits"
        
        var id: String { self.rawValue }
        
        var label: String { self.rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Filter
            HStack {
                Text("Transactions")
                    .font(.sectionHeader)
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
            
            // Optimized Transaction List with Stable Scrolling
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(displayedTransactions, id: \.id) { transaction in
                        CreditCardTransactionRow(transaction: transaction)
                    }
                    
                    // Load More Button (instead of automatic loading)
                    if displayedTransactions.count < filteredTransactions.count {
                        Button(action: {
                            loadMoreItems()
                        }) {
                            HStack {
                                Spacer()
                                Text("Load More")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundColor(.blue)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4) // Add slight padding for better scrolling
            }
            .frame(maxHeight: calculateOptimalHeight()) // Dynamic height based on content
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
            setupInitialData()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                sectionVisible = true
            }
        }
        .onChange(of: filter) { oldValue, newValue in
            updateFilteredTransactions()
        }
    }
    
    // MARK: - Performance Optimized Methods
    
    private func setupInitialData() {
        // Pre-sort transactions by date (newest first) using proper date comparison
        let sortedTransactions = statement.transactions.sorted { first, second in
            // Convert date strings to actual dates for proper comparison
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            guard let firstDate = dateFormatter.date(from: first.date),
                  let secondDate = dateFormatter.date(from: second.date) else {
                // Fallback to string comparison if date parsing fails
                return first.date > second.date
            }
            
            // Sort by date descending (newest first)
            return firstDate > secondDate
        }
        
        // Cache all filtered versions to avoid recomputation
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                self.filteredTransactions = sortedTransactions
                self.loadInitialItems()
            }
        }
    }
    
    private func updateFilteredTransactions() {
        // Apply the same proper date sorting
        let allTransactions = statement.transactions.sorted { first, second in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            guard let firstDate = dateFormatter.date(from: first.date),
                  let secondDate = dateFormatter.date(from: second.date) else {
                return first.date > second.date
            }
            
            return firstDate > secondDate
        }
        
        let newFiltered: [StatementTransaction]
        switch filter {
        case .all:
            newFiltered = allTransactions
        case .debit:
            newFiltered = allTransactions.filter { $0.type == .debit }
        case .credit:
            newFiltered = allTransactions.filter { $0.type == .credit }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            filteredTransactions = newFiltered
            itemsToShow = min(itemsPerPage, newFiltered.count)
            displayedTransactions = Array(newFiltered.prefix(itemsToShow))
        }
    }
    
    private func loadInitialItems() {
        itemsToShow = min(itemsPerPage, filteredTransactions.count)
        displayedTransactions = Array(filteredTransactions.prefix(itemsToShow))
    }
    
    private func loadMoreItems() {
        guard displayedTransactions.count < filteredTransactions.count else { return }
        
        let newItemsToShow = min(itemsToShow + itemsPerPage, filteredTransactions.count)
        let newItems = Array(filteredTransactions.prefix(newItemsToShow))
        
        withAnimation(.easeInOut(duration: 0.2)) {
            itemsToShow = newItemsToShow
            displayedTransactions = newItems
        }
    }
    
    private func calculateOptimalHeight() -> CGFloat {
        // Transaction row height (padding + content) is approximately 80 points
        let rowHeight: CGFloat = 80
        let spacing: CGFloat = 12
        let loadMoreButtonHeight: CGFloat = 44
        let maxVisibleRows = 4 // Reduced for better performance
        
        // Calculate height based on actual displayed transactions
        let actualRows = displayedTransactions.count
        
        if actualRows == 0 {
            return 100 // Minimum height for empty state
        } else if actualRows <= maxVisibleRows {
            // Show all transactions without scrolling
            var totalHeight = CGFloat(actualRows) * rowHeight + CGFloat(max(0, actualRows - 1)) * spacing
            
            // Add load more button height if there are more items
            if displayedTransactions.count < filteredTransactions.count {
                totalHeight += loadMoreButtonHeight + spacing
            }
            
            return min(totalHeight + 20, 350) // Add padding, max 350 for performance
        } else {
            // Show fixed height for many transactions (scrollable)
            return 350 // Reduced max height for better performance
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