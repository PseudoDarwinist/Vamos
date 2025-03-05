import SwiftUI
import Combine

struct HomeView: View {
    @State private var monthSummary: MonthSummary = MonthSummary.sample
    @State private var showAllCategories: Bool = false
    @State private var isLoading: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var selectedCategory: Category?
    @State private var navigateToCategory = false
    
    // Add an ObservedObject for the transaction store to ensure updates
    @ObservedObject private var transactionStore = TransactionStore.shared
    
    // Services
    private let geminiService = GeminiService()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.background
                    .edgesIgnoringSafeArea(.all)
                
                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header component
                        HeaderComponent(monthSummary: monthSummary)
                            .padding(.horizontal)
                        
                        // Spending story card
                        SpendingStoryCard(
                            narrativeSummary: monthSummary.narrativeSummary,
                            transactionCount: transactionStore.transactions.count
                        )
                        .padding(.horizontal)
                        
                        // Overall Spending
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Overall Spending")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        showAllCategories.toggle()
                                    }
                                }) {
                                    Text(showAllCategories ? "Show Less" : "See All")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.accent)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Category totals based on TransactionStore
                            VStack(spacing: 12) {
                                let categoryTotals = transactionStore.getCategoryTotals()
                                
                                if categoryTotals.isEmpty {
                                    // Empty state
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 12) {
                                            Image(systemName: "leaf.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.primaryGreen.opacity(0.5))
                                            
                                            Text("No transactions yet")
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundColor(.textPrimary)
                                            
                                            Text("Your spending will appear here")
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundColor(.textSecondary)
                                        }
                                        .padding(.vertical, 30)
                                        Spacer()
                                    }
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                } else {
                                    // Only show up to 3 categories when collapsed
                                    let visibleCategories = showAllCategories ? categoryTotals : 
                                                         categoryTotals.count > 3 ? Array(categoryTotals.prefix(3)) : categoryTotals
                                    
                                    ForEach(visibleCategories) { categoryTotal in
                                        CategoryTotalItem(
                                            category: categoryTotal.category,
                                            amount: categoryTotal.amount,
                                            description: "\(categoryTotal.count) transaction\(categoryTotal.count != 1 ? "s" : "")"
                                        )
                                        .onTapGesture {
                                            selectedCategory = categoryTotal.category
                                            navigateToCategory = true
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Bottom spacer for tab bar
                        Spacer(minLength: 80)
                    }
                    .padding(.top)
                    
                    // Navigation link to CategoryDetailView (changed from CategoryDetailView to our common version)
                    NavigationLink(
                        destination: selectedCategory.map { CategoryDetailView(category: $0) },
                        isActive: $navigateToCategory
                    ) {
                        EmptyView()
                    }
                }
                
                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryGreen))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        )
                }
            }
            .navigationBarHidden(true)
            .onAppear(perform: loadData)
        }
    }
    
    private func loadData() {
        isLoading = true
        
        // Calculate total amount from all transactions
        let totalAmount = transactionStore.transactions.reduce(Decimal(0)) { $0 + $1.amount }
        
        // Update month summary with actual data
        monthSummary = MonthSummary(
            id: UUID(), // Create a new ID to force SwiftUI to recognize the change
            month: monthSummary.month,
            totalSpent: totalAmount,
            transactionCount: transactionStore.transactions.count,
            categorySummaries: [], // This could be populated if needed
            narrativeSummary: monthSummary.narrativeSummary
        )
        
        // If there are no transactions, set a default narrative and stop loading
        if transactionStore.transactions.isEmpty {
            isLoading = false
            monthSummary.narrativeSummary = "Add your first transaction to see insights about your spending habits."
            return
        }
        
        // Generate narrative summary using actual transactions
        geminiService.generateNarrativeSummary(transactions: transactionStore.transactions)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("Error generating narrative: \(error)")
                        // Fallback narrative if API fails
                        monthSummary.narrativeSummary = "Like a garden, your finances have patterns. Your biggest expense was in \(self.getTopCategory()). Keep nurturing your financial garden and watch your savings grow!"
                    }
                },
                receiveValue: { narrativeSummary in
                    monthSummary.narrativeSummary = narrativeSummary
                }
            )
            .store(in: &cancellables)
    }
    
    // Helper to get top category for the fallback narrative
    private func getTopCategory() -> String {
        let categoryTotals = transactionStore.getCategoryTotals()
        if let topCategory = categoryTotals.first {
            return topCategory.category.name
        }
        return "your top category"
    }
}

// Category total item component
struct CategoryTotalItem: View {
    let category: Category
    let amount: Decimal
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(category.color)
            }
            
            // Category and description
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(NSDecimalNumber(decimal: amount).stringValue)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}