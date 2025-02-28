import SwiftUI
import Combine

struct HomeView: View {
    @State private var monthSummary: MonthSummary = MonthSummary.sample
    @State private var recentTransactions: [Transaction] = Transaction.sampleTransactions
    @State private var isLoading: Bool = false
    @State private var showAllTransactions: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    
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
                            transactionCount: monthSummary.transactionCount
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
                            
                            // Merchant totals instead of individual transactions
                            VStack(spacing: 12) {
                                MerchantTotalItem(
                                    merchantName: "Swiggy",
                                    icon: "takeoutbag.and.cup.and.straw.fill",
                                    amount: 15000,
                                    description: "Total spending"
                                )
                                
                                MerchantTotalItem(
                                    merchantName: "Amazon",
                                    icon: "cart.fill",
                                    amount: 21450,
                                    description: "Total spending"
                                )
                                
                                if showAllTransactions {
                                    MerchantTotalItem(
                                        merchantName: "Uber",
                                        icon: "car.fill",
                                        amount: 8500,
                                        description: "Total spending"
                                    )
                                    
                                    MerchantTotalItem(
                                        merchantName: "Other",
                                        icon: "briefcase.fill",
                                        amount: 5780,
                                        description: "Total spending"
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
        
        // Simulate network call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Generate nature-themed narrative summary using Gemini
            let naturePrompt = """
            Create a nature-themed summary of the following spending data using plant/garden metaphors:
            - Total spending: ₹22,450
            - Biggest expense: Amazon at ₹21,450
            - Food spending increased by 12% from last month
            
            Keep it conversational and limit to 2-3 sentences.
            """
            
            geminiService.generateNarrativeSummary(transactions: recentTransactions)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        isLoading = false
                        if case .failure(let error) = completion {
                            print("Error generating narrative: \(error)")
                            // Fallback narrative if API fails
                            monthSummary.narrativeSummary = "Like a garden, your finances have patterns. Your biggest expense was at Amazon (that's like the tallest tree in your financial forest). Your food spending has grown by 12% since last month — perhaps time to prune a bit?"
                        }
                    },
                    receiveValue: { narrativeSummary in
                        monthSummary.narrativeSummary = narrativeSummary
                    }
                )
                .store(in: &cancellables)
        }
    }
}

// New component for merchant total items
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
