import SwiftUI

struct CategoryTransactionsView: View {
    let category: Category
    let merchantFilter: String?
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var transactionStore = TransactionStore.shared
    
    // CHANGE 1: Add state variables for navigation
    @State private var selectedTransaction: Transaction? = nil
    @State private var navigateToTransaction = false
    
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
        // CHANGE 2: Use NavigationView to simplify navigation
        NavigationView {
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
                                // CHANGE 3: Modified transaction item navigation
                                ForEach(filteredTransactions.sorted(by: { $0.date > $1.date })) { transaction in
                                    NavigationLink {
                                        // This is what will be shown when the item is tapped
                                        TransactionDetailView(transaction: transaction)
                                    } label: {
                                        // This is what will be displayed in the list
                                        CategoryTransactionItem(transaction: transaction)
                                    }
                                    .buttonStyle(PlainButtonStyle())
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
            .onAppear {
                print("🔍 CategoryTransactionsView appeared - \(filteredTransactions.count) transactions")
                if merchantFilter != nil {
                    print("🔍 Merchant filter: \(merchantFilter!)")
                }
                // Log transactions for debugging
                for transaction in filteredTransactions {
                    print("🔍 Transaction: \(transaction.merchant) - \(transaction.amount)")
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

// CHANGE 4: Simplified TransactionDetailView
struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.presentationMode) var presentationMode
    
    // Format amount - moved outside of body
    private var formattedAmount: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let amount = NSDecimalNumber(decimal: transaction.amount)
        return "₹\(numberFormatter.string(from: amount) ?? amount.stringValue)"
    }
    
    // Format date - moved outside of body
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: transaction.date)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            // Main content
            VStack(spacing: 0) {
                // Header with back button
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
                    
                    Text("Transaction Details")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // Empty view for balance
                    Color.clear
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 16)
                
                // Transaction card with natural language
                VStack(alignment: .center, spacing: 20) {
                    // Merchant and category icon
                    ZStack {
                        Circle()
                            .fill(transaction.category.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: transaction.category.icon)
                            .font(.system(size: 32))
                            .foregroundColor(transaction.category.color)
                    }
                    
                    // Natural language transaction info - simplified without local variables
                    VStack(spacing: 8) {
                        Text("You spent")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.textSecondary)
                        
                        Text(formattedAmount)
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primaryGreen)
                        
                        Text("at \(transaction.merchant)")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text("on \(formattedDate)")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    
                    // Transaction source and category
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: sourceTypeIcon(transaction.sourceType))
                                .foregroundColor(.textSecondary)
                            
                            Text(sourceTypeName(transaction.sourceType))
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                        
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.textSecondary)
                            
                            Text(transaction.category.name)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    // Notes if any
                    if let notes = transaction.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            Text(notes)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
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