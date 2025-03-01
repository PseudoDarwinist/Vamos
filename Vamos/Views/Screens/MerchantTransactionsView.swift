import SwiftUI

struct MerchantTransactionsView: View {
    let category: Category
    let merchantName: String
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var transactionStore = TransactionStore.shared
    
    // Get transactions for this merchant in this category
    private var merchantTransactions: [Transaction] {
        // Use the custom filtering logic to handle special cases like food delivery
        return transactionStore.transactions.filter { transaction in
            // First check if the transaction belongs to the specified category
            guard transaction.category.name == category.name else {
                return false
            }
            
            let transactionMerchant = transaction.merchant.lowercased()
            
            // For food delivery platforms
            if merchantName == "Swiggy" {
                return transactionMerchant.contains("swiggy") ||
                       (transactionMerchant.contains("kfc") && transactionMerchant.contains("swiggy")) ||
                       (transactionMerchant.contains("nazeer") && transactionMerchant.contains("swiggy")) ||
                       (transactionMerchant.contains("starbucks") && transactionMerchant.contains("swiggy")) ||
                       (transactionMerchant.contains("mcdonald") && transactionMerchant.contains("swiggy")) ||
                       (transactionMerchant.contains("burger king") && transactionMerchant.contains("swiggy")) ||
                       (transactionMerchant.contains("domino") && transactionMerchant.contains("swiggy"))
            } else if merchantName == "Zomato" {
                return transactionMerchant.contains("zomato") ||
                       (transactionMerchant.contains("kfc") && transactionMerchant.contains("zomato")) ||
                       (transactionMerchant.contains("nazeer") && transactionMerchant.contains("zomato")) ||
                       (transactionMerchant.contains("starbucks") && transactionMerchant.contains("zomato")) ||
                       (transactionMerchant.contains("mcdonald") && transactionMerchant.contains("zomato")) ||
                       (transactionMerchant.contains("burger king") && transactionMerchant.contains("zomato")) ||
                       (transactionMerchant.contains("domino") && transactionMerchant.contains("zomato"))
            } else if merchantName == "Amazon" {
                return transactionMerchant.contains("amazon")
            } else if merchantName == "Uber" {
                return transactionMerchant.contains("uber") ||
                       transactionMerchant.contains("ola") ||
                       transactionMerchant.contains("taxi") ||
                       transactionMerchant.contains("petrol") ||
                       transactionMerchant.contains("gas") ||
                       transactionMerchant.contains("fuel")
            } else if merchantName == "KFC" {
                // For specific restaurants, only show direct transactions (not through delivery platforms)
                return transactionMerchant.contains("kfc") && 
                       !transactionMerchant.contains("swiggy") && 
                       !transactionMerchant.contains("zomato")
            } else {
                // Direct match for specific merchant
                return transactionMerchant.contains(merchantName.lowercased())
            }
        }
    }
    
    // Calculate total spending for this merchant
    private var totalSpending: Decimal {
        merchantTransactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            // Main content
            VStack(spacing: 0) {
                // Header with back button and merchant name
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryGreen)
                            .padding(8)
                            .background(Color.secondaryGreen.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(merchantName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // Empty view for balance
                    Color.clear
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
                
                // Merchant summary card
                MerchantSummaryCard(
                    category: category,
                    merchantName: merchantName,
                    totalSpent: totalSpending,
                    transactionCount: merchantTransactions.count
                )
                .padding(.horizontal)
                .padding(.bottom)
                
                // Transaction list
                if merchantTransactions.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.primaryGreen.opacity(0.5))
                        
                        Text("No transactions yet")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text("Your transactions at \(merchantName) will appear here")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    // Title for transactions section
                    HStack {
                        Text("Transactions")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(merchantTransactions.sorted(by: { $0.date > $1.date })) { transaction in
                                TransactionListItem(transaction: transaction)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                        
                        // Bottom spacer for tab bar
                        Spacer(minLength: 80)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// Merchant summary card
struct MerchantSummaryCard: View {
    let category: Category
    let merchantName: String
    let totalSpent: Decimal
    let transactionCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: TransactionStore.shared.iconForMerchant(merchantName))
                        .font(.system(size: 24))
                        .foregroundColor(category.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent at \(merchantName)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.textSecondary)
                    
                    Text("₹\(NSDecimalNumber(decimal: totalSpent).stringValue)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("\(transactionCount) transaction\(transactionCount != 1 ? "s" : "")")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// Transaction list item
struct TransactionListItem: View {
    let transaction: Transaction
    
    // Natural language description of the transaction
    private var transactionDescription: String {
        // Format currency with appropriate formatting
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        
        let amount = NSDecimalNumber(decimal: transaction.amount)
        let amountStr = "₹\(numberFormatter.string(from: amount) ?? amount.stringValue)"
        
        let dateStr = formatDate(transaction.date)
        return "You spent \(amountStr) at \(transaction.merchant) on \(dateStr)"
    }
    
    // Format date for natural language
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Small category icon
            ZStack {
                Circle()
                    .fill(transaction.category.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: transaction.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(transaction.category.color)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Natural language description
                Text(transactionDescription)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                
                // Source type indicator
                HStack(spacing: 4) {
                    Image(systemName: sourceTypeIcon(transaction.sourceType))
                        .font(.system(size: 12))
                    
                    Text(sourceTypeName(transaction.sourceType))
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundColor(.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
    
    // Helper for source type icon
    private func sourceTypeIcon(_ sourceType: SourceType) -> String {
        switch sourceType {
        case .manual:
            return "keyboard"
        case .scanned:
            return "camera"
        case .digital:
            return "doc.text"
        }
    }
    
    // Helper for source type name
    private func sourceTypeName(_ sourceType: SourceType) -> String {
        switch sourceType {
        case .manual:
            return "Manual Entry"
        case .scanned:
            return "Scanned Receipt"
        case .digital:
            return "Digital Invoice"
        }
    }
}

struct MerchantTransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        MerchantTransactionsView(
            category: Category.sample(name: "Food & Dining"),
            merchantName: "Swiggy"
        )
    }
} 