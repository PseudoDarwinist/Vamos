import SwiftUI

struct CategoryDetailView: View {
    let category: Category
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var transactionStore = TransactionStore.shared
    @State private var selectedMerchant: String?
    @State private var navigateToMerchant = false
    
    // Calculate total spending in this category
    private var totalSpending: Decimal {
        transactionStore.totalForCategory(category.name)
    }
    
    // Get all transactions in this category
    private var categoryTransactions: [Transaction] {
        transactionStore.transactionsForCategory(category.name)
            .sorted(by: { $0.date > $1.date }) // Sort by date, newest first
    }
    
    // Get all merchants in this category
    private var merchantsInCategory: [MerchantTotal] {
        transactionStore.getMerchantTotalsInCategory(categoryName: category.name)
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
                    
                    Text(category.name)
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
                    transactionCount: categoryTransactions.count,
                    merchantName: nil
                )
                .padding(.horizontal)
                .padding(.bottom)
                
                // Content based on transactions or merchants
                if categoryTransactions.isEmpty {
                    // Empty state
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
                    // Show merchants instead of transactions directly
                    ScrollView {
                        VStack(spacing: 16) {
                            // Title for merchants section
                            HStack {
                                Text("Merchants")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // List all merchants in this category
                            ForEach(merchantsInCategory, id: \.merchantName) { merchant in
                                MerchantListItem(
                                    merchantName: merchant.merchantName,
                                    icon: merchant.icon,
                                    amount: merchant.amount,
                                    count: merchant.count
                                )
                                .padding(.horizontal)
                                .onTapGesture {
                                    selectedMerchant = merchant.merchantName
                                    navigateToMerchant = true
                                }
                            }
                        }
                        .padding(.bottom, 100) // For tab bar space
                    }
                }
                
                // Navigation link for merchant details
                NavigationLink(
                    destination: selectedMerchant.map { merchantName in
                        MerchantTransactionsView(
                            category: category,
                            merchantName: merchantName
                        )
                    },
                    isActive: $navigateToMerchant
                ) {
                    EmptyView()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🔍 CategoryDetailView appeared for \(category.name) - Transactions count: \(categoryTransactions.count)")
            print("🔍 Merchants in category: \(merchantsInCategory.count)")
        }
    }
}

// Merchant list item component
struct MerchantListItem: View {
    let merchantName: String
    let icon: String
    let amount: Decimal
    let count: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Merchant icon
            ZStack {
                Circle()
                    .fill(Color.secondaryGreen.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.primaryGreen)
            }
            
            // Merchant name and transaction count
            VStack(alignment: .leading, spacing: 4) {
                Text(merchantName)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text("\(count) transaction\(count != 1 ? "s" : "")")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Amount and chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(NSDecimalNumber(decimal: amount).stringValue)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

struct CategoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryDetailView(category: Category.sample(name: "Food & Drink"))
    }
}