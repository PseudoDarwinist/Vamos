import SwiftUI

struct CardStatementHistoryView: View {
    @ObservedObject var viewModel: StatementProcessorViewModel
    
    var body: some View {
        ZStack {
            // Background
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            if viewModel.savedStatements.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Statements Found")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                    
                    Text("Upload your first credit card statement to see it here")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                // Statement list
                List {
                    ForEach(viewModel.savedStatements, id: \.self) { statement in
                        NavigationLink(destination: CreditCardSummaryView(statement: statement, rawTransactionCount: 0)) {
                            StatementListItemView(statement: statement)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                _ = viewModel.deleteStatement(statement)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("Statement History")
        .onAppear {
            // Refresh data when view appears
            viewModel.loadAllStatements()
        }
    }
}

struct StatementListItemView: View {
    let statement: CreditCardStatement
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card info
            HStack {
                Text(statement.card?.issuer ?? "Credit Card")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.medium)
                
                Spacer()
                
                if let last4 = statement.card?.last4 {
                    Text("••••\(last4)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            
            // Period
            if let period = statement.card?.statementPeriod {
                Text("\(formatDate(period.from)) - \(formatDate(period.to))")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            // Summary
            if let summary = statement.summary {
                HStack {
                    Label(
                        title: { 
                            Text("\(statement.transactions.count) transactions") 
                                .font(.system(.caption, design: .rounded))
                        },
                        icon: { 
                            Image(systemName: "creditcard") 
                                .font(.system(.caption)) 
                        }
                    )
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if let total = summary.totalSpend {
                        Text(formatAmount(total, currency: "INR"))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Format date for display
    private func formatDate(_ dateString: String) -> String {
        // Convert from ISO format to display format
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd MMM yyyy"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        return dateString
    }
    
    // Format amount
    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0 // Round to whole number
        formatter.usesGroupingSeparator = false // No thousands separators
        formatter.currencySymbol = currencySymbol(for: currency)
        
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
    
    // Get currency symbol
    private func currencySymbol(for currencyCode: String) -> String {
        switch currencyCode {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return currencyCode
        }
    }
}

extension CreditCardStatement {
    var id: String {
        // Create a unique identifier for the statement
        var identifier = ""
        if let card = self.card {
            if let issuer = card.issuer {
                identifier += issuer
            }
            if let last4 = card.last4 {
                identifier += last4
            }
            if let period = card.statementPeriod {
                identifier += period.from + period.to
            }
        }
        // Use the first transaction date as a fallback
        if identifier.isEmpty, let firstTransaction = transactions.first {
            identifier = firstTransaction.date
        }
        return identifier
    }
}

struct CardStatementHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CardStatementHistoryView(viewModel: previewViewModel)
        }
    }
    
    static var previewViewModel: StatementProcessorViewModel {
        let viewModel = StatementProcessorViewModel(context: PersistenceManager.shared.viewContext)
        
        // Add some sample data
        let cardInfo = CardInfo(
            issuer: "HDFC Bank",
            product: "Regalia",
            last4: "1234",
            statementPeriod: StatementPeriod(from: "2023-04-01", to: "2023-04-30")
        )
        
        let summary = StatementSummary(
            totalSpend: 25689.50,
            openingBalance: 10000.0,
            closingBalance: 35689.50,
            minPayment: 1784.50,
            dueDate: "2023-05-15"
        )
        
        let transactions = [
            StatementTransaction(
                date: "2023-04-05",
                description: "Amazon.in Order",
                amount: 1299.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "Shopping", merchant: "Amazon")
            ),
            StatementTransaction(
                date: "2023-04-10",
                description: "Swiggy Order",
                amount: 450.0,
                currency: "INR",
                type: .debit,
                derived: DerivedInfo(category: "Food & Dining", merchant: "Swiggy")
            )
        ]
        
        let statement = CreditCardStatement(
            card: cardInfo,
            transactions: transactions,
            summary: summary
        )
        
        viewModel.statement = statement
        
        return viewModel
    }
} 