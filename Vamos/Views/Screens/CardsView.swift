import SwiftUI
import Combine

struct CardsView: View {
    @StateObject private var cardStore = CardStore.shared
    @ObservedObject private var cashbackStore = CashbackStore.shared
    
    @State private var selectedCard: Card?
    @State private var showingAddCard = false
    @State private var showingScanStatement = false
    @State private var showingManualEntry = false
    @State private var navigateToCardDetail = false
    @State private var showingDeleteConfirmation = false
    @State private var cardToDelete: UUID? = nil
    
    // Total cashback across all cards
    private var totalCashback: Decimal {
        cashbackStore.getTotalCashback()
    }
    
    var body: some View {
        NavigationView {
            CardsContent(
                cardStore: cardStore,
                cashbackStore: cashbackStore,
                totalCashback: totalCashback,
                selectedCard: $selectedCard,
                showingAddCard: $showingAddCard,
                showingScanStatement: $showingScanStatement,
                showingManualEntry: $showingManualEntry,
                navigateToCardDetail: $navigateToCardDetail,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                cardToDelete: $cardToDelete
            )
        }
        .onAppear {
            print("🔍 CardsView appeared - Cards count: \(cardStore.cards.count)")
            if cardStore.cards.isEmpty {
                print("🔍 CardsView - No cards found")
            } else {
                print("🔍 CardsView - Cards found: \(cardStore.cards.count)")
                cardStore.cards.forEach { card in
                    print("🔍 Card: \(card.nickname) - \(card.issuer) - \(card.lastFourDigits)")
                }
            }
            
            // Force a refresh
            DispatchQueue.main.async {
                cardStore.objectWillChange.send()
            }
        }
    }
}

private struct CardsContent: View {
    let cardStore: CardStore
    let cashbackStore: CashbackStore
    let totalCashback: Decimal
    @Binding var selectedCard: Card?
    @Binding var showingAddCard: Bool
    @Binding var showingScanStatement: Bool
    @Binding var showingManualEntry: Bool
    @Binding var navigateToCardDetail: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var cardToDelete: UUID?
    
    // Format currency
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₹0.00"
    }
    
    var body: some View {
        ZStack {
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    HeaderView()
                    
                    CashbackSummaryView(totalCashback: totalCashback)
                    
                    ActionButtonsView(
                        showingScanStatement: $showingScanStatement,
                        showingManualEntry: $showingManualEntry
                    )
                    
                    CardsSection(
                        cardStore: cardStore,
                        cashbackStore: cashbackStore,
                        showingAddCard: $showingAddCard,
                        selectedCard: $selectedCard,
                        navigateToCardDetail: $navigateToCardDetail,
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        cardToDelete: $cardToDelete
                    )
                    
                    if !cashbackStore.entries.isEmpty {
                        MonthlyInsightsView(cashbackStore: cashbackStore)
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.horizontal)
            }
            
            NavigationLink(
                destination: selectedCard.map { CardDetailView(card: $0) },
                isActive: $navigateToCardDetail
            ) {
                EmptyView()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddCard) {
            AddCardView()
        }
        .sheet(isPresented: $showingScanStatement) {
            ScanStatementView()
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .confirmationDialog(
            "Delete Card",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = cardToDelete {
                    cardStore.deleteCard(id: id)
                }
            }
            Button("Cancel", role: .cancel) {
                cardToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this card? This will also delete all associated cashback entries.")
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("bloom")
                .font(.system(.title, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primaryGreen)
            
            Text("My Cards & Cashback")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            ZStack(alignment: .topTrailing) {
                Color.white
                    .cornerRadius(16)
                
                Circle()
                    .fill(Color.primaryGreen.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .offset(x: 20, y: -20)
                
                Circle()
                    .fill(Color.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .offset(x: -30, y: 30)
            }
        )
    }
}

private struct CashbackSummaryView: View {
    let totalCashback: Decimal
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₹0.00"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Cashback Earned")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.textPrimary)
            
            Text(formatCurrency(totalCashback))
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primaryGreen)
            
            Text("This Year")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondaryGreen.opacity(0.15))
        .cornerRadius(16)
    }
}

private struct ActionButtonsView: View {
    @Binding var showingScanStatement: Bool
    @Binding var showingManualEntry: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                showingScanStatement = true
            }) {
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                    Text("Scan Statement")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.primaryGreen)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.system(.subheadline, design: .rounded))
            }
            
            Button(action: {
                showingManualEntry = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Manually")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.primaryGreen)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primaryGreen, lineWidth: 1)
                )
                .font(.system(.subheadline, design: .rounded))
            }
        }
    }
}

private struct CardsSection: View {
    let cardStore: CardStore
    let cashbackStore: CashbackStore
    @Binding var showingAddCard: Bool
    @Binding var selectedCard: Card?
    @Binding var navigateToCardDetail: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var cardToDelete: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Cards")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.textPrimary)
                .padding(.horizontal)
            
            // Force unwrap the cards array to ensure we're checking the actual array
            let cards = cardStore.cards
            
            if cards.isEmpty {
                EmptyCardsView(showingAddCard: $showingAddCard)
            } else {
                CardsList(
                    cardStore: cardStore,
                    cashbackStore: cashbackStore,
                    selectedCard: $selectedCard,
                    navigateToCardDetail: $navigateToCardDetail,
                    showingDeleteConfirmation: $showingDeleteConfirmation,
                    cardToDelete: $cardToDelete
                )
                
                AddCardButton(showingAddCard: $showingAddCard)
            }
        }
        .onAppear {
            print("🔍 CardsSection appeared - Cards count: \(cardStore.cards.count)")
            if cardStore.cards.isEmpty {
                print("🔍 CardsSection - No cards found, showing EmptyCardsView")
            } else {
                print("🔍 CardsSection - Cards found: \(cardStore.cards.count), showing CardsList")
                cardStore.cards.forEach { card in
                    print("🔍 CardsSection - Card: \(card.id) - \(card.nickname)")
                }
            }
        }
    }
}

private struct EmptyCardsView: View {
    @Binding var showingAddCard: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "creditcard")
                .font(.system(size: 50))
                .foregroundColor(.secondaryGreen.opacity(0.5))
            
            Text("No cards added yet")
                .font(.system(.title3, design: .rounded))
                .foregroundColor(.textPrimary)
            
            Text("Add your first card to start tracking cashback")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingAddCard = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Your First Card")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.primaryGreen)
                .foregroundColor(.white)
                .cornerRadius(25)
                .font(.system(.body, design: .rounded))
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
    }
}

private struct CardsList: View {
    @ObservedObject var cardStore: CardStore
    let cashbackStore: CashbackStore
    @Binding var selectedCard: Card?
    @Binding var navigateToCardDetail: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var cardToDelete: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(cardStore.cards) { card in
                CardListItem(
                    card: card,
                    cashbackAmount: cashbackStore.getCashbackForCard(cardId: card.id)
                )
                .onTapGesture {
                    selectedCard = card
                    navigateToCardDetail = true
                }
                .onLongPressGesture {
                    cardToDelete = card.id
                    showingDeleteConfirmation = true
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            print("🔍 CardsList appeared - Cards count: \(cardStore.cards.count)")
            if cardStore.cards.isEmpty {
                print("🔍 CardsList - No cards found")
            } else {
                print("🔍 CardsList - Cards found: \(cardStore.cards.count)")
                cardStore.cards.forEach { card in
                    print("🔍 CardsList - Card: \(card.nickname) - \(card.issuer) - \(card.lastFourDigits)")
                }
            }
        }
    }
}

private struct AddCardButton: View {
    @Binding var showingAddCard: Bool
    
    var body: some View {
        Button(action: {
            showingAddCard = true
        }) {
            HStack {
                Circle()
                    .fill(Color.accent.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "plus")
                            .foregroundColor(.accent)
                    )
                
                Text("Add a new card")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.accent)
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accent.opacity(0.3), lineWidth: 1)
                    .dashStyle(dashPattern: [4])
            )
        }
    }
}

private struct MonthlyInsightsView: View {
    let cashbackStore: CashbackStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Insights")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.textPrimary)
                .padding(.top, 20)
                .padding(.horizontal)
            
            MonthlyCashbackChart(data: cashbackStore.getMonthlyCashback())
                .frame(height: 150)
                .padding()
                .background(Color.white)
                .cornerRadius(16)
        }
    }
}

// Card List Item Component
struct CardListItem: View {
    let card: Card
    let cashbackAmount: Decimal
    
    var body: some View {
        HStack(spacing: 16) {
            // Card issuer logo
            ZStack {
                Rectangle()
                    .fill(Color(hex: card.colorHex))
                    .frame(width: 50, height: 35)
                    .cornerRadius(5)
                
                Text(card.issuer)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            // Card details
            VStack(alignment: .leading, spacing: 4) {
                Text(card.nickname)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text("••••\(card.lastFourDigits)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Cashback amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(NSDecimalNumber(decimal: cashbackAmount).stringValue)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primaryGreen)
                
                Text("Long press to delete")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// Monthly Cashback Chart Component
struct MonthlyCashbackChart: View {
    let data: [MonthCashbackData]
    
    private var maxValue: Decimal {
        data.map { $0.amount }.max() ?? 1
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data) { item in
                VStack {
                    // Bar
                    Rectangle()
                        .fill(calculateColor(amount: item.amount))
                        .frame(width: 30, height: calculateHeight(amount: item.amount, maxHeight: 100))
                    
                    // Month label
                    Text(item.month)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.top, 20) // Space for labels at the top
    }
    
    // Calculate bar height based on amount relative to max
    private func calculateHeight(amount: Decimal, maxHeight: CGFloat) -> CGFloat {
        if maxValue == 0 { return 0 }
        let ratio = CGFloat(NSDecimalNumber(decimal: amount).doubleValue / NSDecimalNumber(decimal: maxValue).doubleValue)
        return max(20, ratio * maxHeight) // Minimum bar height of 20
    }
    
    // Color bars based on value (green gradient)
    private func calculateColor(amount: Decimal) -> Color {
        if maxValue == 0 { return .secondaryGreen.opacity(0.3) }
        let ratio = Double(NSDecimalNumber(decimal: amount).doubleValue / NSDecimalNumber(decimal: maxValue).doubleValue)
        
        // Full opacity for highest, lower for others
        if ratio > 0.9 {
            return .primaryGreen
        } else {
            return .secondaryGreen.opacity(0.3 + (0.7 * ratio))
        }
    }
}

// Extension for dashed borders
extension View {
    func dashStyle(dashPattern: [CGFloat] = [5, 5]) -> some View {
        self.overlay(
            GeometryReader { geometry in
                Path { path in
                    path.addLines([
                        CGPoint(x: 0, y: 0),
                        CGPoint(x: geometry.size.width, y: 0),
                        CGPoint(x: geometry.size.width, y: geometry.size.height),
                        CGPoint(x: 0, y: geometry.size.height),
                        CGPoint(x: 0, y: 0)
                    ])
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: dashPattern))
            }
        )
    }
}

struct CardsView_Previews: PreviewProvider {
    static var previews: some View {
        CardsView()
    }
}
