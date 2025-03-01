import SwiftUI

struct CategoriesView: View {
    @ObservedObject private var transactionStore = TransactionStore.shared
    @State private var selectedCategory: Category?
    @State private var navigateToCategory = false
    
    // Get all unique categories with transactions
    private var categoriesWithTransactions: [Category] {
        let categoriesInUse = transactionStore.transactions.map { $0.category }
        var uniqueCategories: [Category] = []
        
        // Filter unique categories by name
        for category in categoriesInUse {
            if !uniqueCategories.contains(where: { $0.name == category.name }) {
                uniqueCategories.append(category)
            }
        }
        
        return uniqueCategories.sorted(by: { $0.name < $1.name })
    }
    
    // Calculate total for each category
    private func totalForCategory(_ category: Category) -> Decimal {
        transactionStore.transactions
            .filter { $0.category.name == category.name }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Count transactions for each category
    private func transactionCountForCategory(_ category: Category) -> Int {
        transactionStore.transactions
            .filter { $0.category.name == category.name }
            .count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.background
                    .edgesIgnoringSafeArea(.all)
                
                // Main content
                VStack(spacing: 0) {
                    // Header
                    Text("Categories")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .padding(.top)
                        .padding(.bottom, 16)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if categoriesWithTransactions.isEmpty {
                                // Empty state
                                VStack(spacing: 20) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.primaryGreen.opacity(0.5))
                                    
                                    Text("No categories yet")
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.textPrimary)
                                    
                                    Text("Add your first transaction to see categories")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                .padding(.horizontal)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                                .padding(.top, 40)
                            } else {
                                ForEach(categoriesWithTransactions) { category in
                                    CategoryCard(
                                        category: category,
                                        total: totalForCategory(category),
                                        transactionCount: transactionCountForCategory(category)
                                    )
                                    .onTapGesture {
                                        selectedCategory = category
                                        navigateToCategory = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Allow for tab bar
                    }
                    
                    NavigationLink(
                        destination: selectedCategory.map { CategoryTransactionsView(category: $0) },
                        isActive: $navigateToCategory
                    ) {
                        EmptyView()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// Category card for the categories list
struct CategoryCard: View {
    let category: Category
    let total: Decimal
    let transactionCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Category icon
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(category.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text("\(transactionCount) transaction\(transactionCount != 1 ? "s" : "")")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(NSDecimalNumber(decimal: total).stringValue)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView()
    }
}