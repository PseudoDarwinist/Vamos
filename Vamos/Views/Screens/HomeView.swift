import SwiftUI
import Combine

struct HomeView: View {
    @State private var monthSummary: MonthSummary = MonthSummary.sample
    @State private var showAllTransactions: Bool = false
    @State private var isLoading: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    
    // Add an ObservedObject for the transaction store
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
                                        showAllTransactions.toggle()
                                    }
                                }) {
                                    Text(showAllTransactions ? "Show Less" : "See All")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.accent)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Merchant totals based on TransactionStore
                            VStack(spacing: 12) {
                                let merchantTotals = transactionStore.getMerchantTotals()
                                
                                // Only show up to 2 merchants when collapsed
                                let visibleMerchants = showAllTransactions ? merchantTotals : 
                                                     merchantTotals.count > 2 ? Array(merchantTotals.prefix(2)) : merchantTotals
                                
                                ForEach(visibleMerchants) { merchant in
                                    MerchantTotalItem(
                                        merchantName: merchant.merchantName,
                                        icon: merchant.icon,
                                        amount: merchant.amount,
                                        description: "\(merchant.count) transaction\(merchant.count != 1 ? "s" : "")"
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Bottom spacer for tab bar
                        Spacer(minLength: 80)
                    }
                    .padding(.top)
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
        
        // Generate narrative summary using actual transactions
        geminiService.generateNarrativeSummary(transactions: transactionStore.transactions)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("Error generating narrative: \(error)")
                        // Fallback narrative if API fails
                        monthSummary.narrativeSummary = "Like a garden, your finances have patterns. Your biggest expense was at \(self.getTopMerchant()). Keep nurturing your financial garden and watch your savings grow!"
                    }
                },
                receiveValue: { narrativeSummary in
                    monthSummary.narrativeSummary = narrativeSummary
                }
            )
            .store(in: &cancellables)
    }
    
    // Helper to get top merchant for the fallback narrative
    private func getTopMerchant() -> String {
        let merchantTotals = transactionStore.getMerchantTotals()
        if let topMerchant = merchantTotals.max(by: { $0.amount < $1.amount }) {
            return topMerchant.merchantName
        }
        return "your favorite merchant"
    }
}

// Merchant total item component
struct MerchantTotalItem: View {
    let merchantName: String
    let icon: String
    let amount: Double
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.secondaryGreen.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.primaryGreen)
            }
            
            // Merchant and description
            VStack(alignment: .leading, spacing: 4) {
                Text(merchantName)
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
                Text("₹\(Int(amount))")
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