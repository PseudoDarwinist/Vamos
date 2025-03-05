import SwiftUI

struct MerchantTransactionsView: View {
    let category: Category
    let merchantName: String
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var transactionStore = TransactionStore.shared
    @State private var selectedTransaction: Transaction? = nil
    @State private var navigateToTransaction = false
    
    // Get transactions for this merchant in this category
    private var merchantTransactions: [Transaction] {
        // First, filter by category
        let categoryTransactions = transactionStore.transactions.filter { 
            $0.category.name == category.name 
        }
        
        // Debug logging
        print("🔍 DEBUG: Looking for merchant '\(merchantName)' in category '\(category.name)'")
        print("🔍 DEBUG: Found \(categoryTransactions.count) transactions in this category")
        
        // Then filter by merchant name, considering both direct merchants and aggregators
        let filteredTransactions = categoryTransactions.filter { transaction in
            // For consistency with how merchants are grouped in CategoryDetailView
            let groupKey = transaction.aggregator ?? transaction.merchant
            
            // Case-insensitive comparison
            let result = groupKey.lowercased() == merchantName.lowercased()
            
            // Debug logging for each transaction
            print("🔍 DEBUG: Transaction: \(transaction.merchant), Aggregator: \(transaction.aggregator ?? "None"), GroupKey: \(groupKey), Match: \(result)")
            
            return result
        }
        
        print("🔍 DEBUG: Found \(filteredTransactions.count) transactions for merchant '\(merchantName)'")
        
        return filteredTransactions
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
                                NavigationLink {
                                    // Navigate to transaction detail view
                                    TransactionDetailView(transaction: transaction)
                                } label: {
                                    // Use the natural language transaction item
                                    CategoryTransactionItem(transaction: transaction)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
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
            print("🔍 MerchantTransactionsView appeared for \(merchantName) - Transactions count: \(merchantTransactions.count)")
            
            // Log each transaction for debugging
            if !merchantTransactions.isEmpty {
                print("🔍 Merchant transactions:")
                merchantTransactions.forEach { transaction in
                    print("  - \(transaction.merchant): ₹\(transaction.amount) on \(transaction.date)")
                }
            }
        }
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
                    
                    Image(systemName: category.icon)
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