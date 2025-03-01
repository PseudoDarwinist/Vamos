import SwiftUI

struct CategoryTransactionsView: View {
    let category: Category
    let merchantFilter: String?
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var transactionStore = TransactionStore.shared
    
    // Initialize with just a category (for category view)
    init(category: Category) {
        self.category = category
        self.merchantFilter = nil
    }
    
    // Initialize with category and merchant (for merchant-specific view)
    init(category: Category, merchantFilter: String) {
        self.category = category
        self.merchantFilter = merchantFilter
    }
    
    // Filter transactions for the selected category and optional merchant
    private var filteredTransactions: [Transaction] {
        if let merchant = merchantFilter {
            // Filter by both category and merchant
            return transactionStore.transactions.filter { transaction in
                let transactionMerchant = transaction.merchant.lowercased()
                
                // First check if the transaction belongs to the specified category
                guard transaction.category.name == category.name else {
                    return false
                }
                
                // For grouped merchants like Swiggy, check if the merchant contains any of the standard aliases
                if merchant == "Swiggy" {
                    return transactionMerchant.contains("swiggy") ||
                           (transactionMerchant.contains("kfc") && transactionMerchant.contains("swiggy")) ||
                           (transactionMerchant.contains("nazeer") && transactionMerchant.contains("swiggy")) ||
                           (transactionMerchant.contains("starbucks") && transactionMerchant.contains("swiggy")) ||
                           (transactionMerchant.contains("mcdonald") && transactionMerchant.contains("swiggy")) ||
                           (transactionMerchant.contains("burger king") && transactionMerchant.contains("swiggy")) ||
                           (transactionMerchant.contains("domino") && transactionMerchant.contains("swiggy"))
                } else if merchant == "Zomato" {
                    return transactionMerchant.contains("zomato") ||
                           (transactionMerchant.contains("kfc") && transactionMerchant.contains("zomato")) ||
                           (transactionMerchant.contains("nazeer") && transactionMerchant.contains("zomato")) ||
                           (transactionMerchant.contains("starbucks") && transactionMerchant.contains("zomato")) ||
                           (transactionMerchant.contains("mcdonald") && transactionMerchant.contains("zomato")) ||
                           (transactionMerchant.contains("burger king") && transactionMerchant.contains("zomato")) ||
                           (transactionMerchant.contains("domino") && transactionMerchant.contains("zomato"))
                } else if merchant == "Amazon" {
                    return transactionMerchant.contains("amazon")
                } else if merchant == "Uber" {
                    return transactionMerchant.contains("uber") ||
                           transactionMerchant.contains("ola") ||
                           transactionMerchant.contains("taxi") ||
                           transactionMerchant.contains("petrol") ||
                           transactionMerchant.contains("gas") ||
                           transactionMerchant.contains("fuel")
                } else if merchant == "KFC" {
                    // For specific restaurants, only show direct transactions (not through delivery platforms)
                    return transactionMerchant.contains("kfc") && 
                           !transactionMerchant.contains("swiggy") && 
                           !transactionMerchant.contains("zomato")
                } else if merchant == "Other" {
                    // For "Other", exclude all known merchants
                    return !transactionMerchant.contains("amazon") && 
                           !transactionMerchant.contains("swiggy") && 
                           !transactionMerchant.contains("zomato") && 
                           !transactionMerchant.contains("uber") &&
                           !transactionMerchant.contains("ola") &&
                           !transactionMerchant.contains("taxi") &&
                           !transactionMerchant.contains("petrol") &&
                           !transactionMerchant.contains("gas") &&
                           !transactionMerchant.contains("fuel") &&
                           !transactionMerchant.contains("kfc") &&
                           !transactionMerchant.contains("nazeer") &&
                           !transactionMerchant.contains("starbucks") &&
                           !transactionMerchant.contains("mcdonald") &&
                           !transactionMerchant.contains("burger king") &&
                           !transactionMerchant.contains("domino") &&
                           !transactionMerchant.contains("flipkart")
                } else {
                    // Direct match for specific merchant
                    return transactionMerchant.contains(merchant.lowercased())
                }
            }
        } else {
            // Only filter by category
            return transactionStore.transactions.filter { transaction in
                return transaction.category.name == category.name
            }
        }
    }
    
    // Calculate total spending in this category
    private var totalSpending: Decimal {
        filteredTransactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            // Main content
            VStack(spacing: 0) {
                // Header with back button and category name
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
                    
                    Text(merchantFilter ?? category.name)
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
                
                // Category summary card
                CategorySummaryCard(
                    category: category,
                    totalSpent: totalSpending,
                    transactionCount: filteredTransactions.count,
                    merchantName: merchantFilter
                )
                .padding(.horizontal)
                .padding(.bottom)
                
                // Transaction list
                if filteredTransactions.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.primaryGreen.opacity(0.5))
                        
                        Text("No transactions yet")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text("Your \(category.name.lowercased()) spending will appear here")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(filteredTransactions.sorted(by: { $0.date > $1.date })) { transaction in
                                CategoryTransactionItem(transaction: transaction)
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

// Transaction item with natural language format
struct CategoryTransactionItem: View {
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
        Button(action: {
            // Placeholder for navigation to transaction details (Page 3)
            print("Navigate to transaction details for \(transaction.id)")
        }) {
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
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
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

// Preview provider
struct CategoryTransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryTransactionsView(category: Category.sample(name: "Food & Drink"))
    }
}