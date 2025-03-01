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
                    transactionCount: transactionStore.transactionsForCategory(category.name).count,
                    merchantName: nil
                )
                .padding(.horizontal)
                .padding(.bottom)
                
                // Merchants list
                if merchantsInCategory.isEmpty {
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
                    // Title for merchants section
                    HStack {
                        Text("Merchants")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(merchantsInCategory) { merchant in
                                MerchantListItem(
                                    merchantName: merchant.merchantName,
                                    icon: merchant.icon,
                                    amount: merchant.amount,
                                    count: merchant.count
                                ) { merchantName in
                                    selectedMerchant = merchantName
                                    navigateToMerchant = true
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                        
                        // Bottom spacer for tab bar
                        Spacer(minLength: 80)
                    }
                }
            }
            
            // Hidden navigation link
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
        .navigationBarHidden(true)
    }
}

// Merchant list item
struct MerchantListItem: View {
    let merchantName: String
    let icon: String
    let amount: Decimal
    let count: Int
    var onTap: (String) -> Void
    
    var body: some View {
        Button(action: {
            onTap(merchantName)
        }) {
            HStack(spacing: 16) {
                // Merchant icon
                ZStack {
                    Circle()
                        .fill(Color.primaryGreen.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.primaryGreen)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchantName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                    
                    Text("\(count) transaction\(count != 1 ? "s" : "")")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Text("₹\(NSDecimalNumber(decimal: amount).stringValue)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.textPrimary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
    }
}

struct CategoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryDetailView(category: Category.sample(name: "Food & Dining"))
    }
} 