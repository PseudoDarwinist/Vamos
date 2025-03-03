import SwiftUI

struct CardDetailView: View {
    let card: Card
    
    @ObservedObject private var cashbackStore = CashbackStore.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingScanStatement = false
    @State private var showingManualEntry = false
    @State private var showingEditCard = false
    
    // Get entries for this card, sorted by date (newest first)
    private var cardEntries: [CashbackEntry] {
        cashbackStore.getEntriesForCard(cardId: card.id)
            .sorted(by: { $0.periodStart > $1.periodStart })
    }
    
    // Total cashback for this card
    private var totalCashback: Decimal {
        cashbackStore.getCashbackForCard(cardId: card.id)
    }
    
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
            // Background
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
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
                        
                        Text("Card Details")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            showingEditCard = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primaryGreen)
                                .padding(8)
                                .background(Color.secondaryGreen.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Card visualization
                    ZStack {
                        Rectangle()
                            .fill(Color(hex: card.colorHex))
                            .frame(height: 160)
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Card nickname
                            Text(card.nickname)
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Issuer logo
                            ZStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 50, height: 35)
                                    .cornerRadius(5)
                                
                                Text(card.issuer)
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Card number and expiry
                            HStack {
                                Text("•••• •••• •••• \(card.lastFourDigits)")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                // Statement day if available
                                if let statementDay = card.statementDay {
                                    Text("Statement: \(statementDay.ordinal) of month")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    
                    // Total cashback summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cashback Earned with this Card")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text(formatCurrency(totalCashback))
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primaryGreen)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Cashback History
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cashback History")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal)
                        
                        if cardEntries.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.primaryGreen.opacity(0.5))
                                
                                Text("No cashback entries yet")
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Text("Add your first cashback entry")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            // Cashback entries
                            ForEach(cardEntries) { entry in
                                CashbackEntryItem(entry: entry)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 10) {
                        Button(action: {
                            showingScanStatement = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text.viewfinder")
                                Text("Scan")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primaryGreen)
                            .foregroundColor(.white)
                            .cornerRadius(22.5)
                            .font(.system(.subheadline, design: .rounded))
                        }
                        
                        Button(action: {
                            showingManualEntry = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Manual")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .foregroundColor(.primaryGreen)
                            .cornerRadius(22.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22.5)
                                    .stroke(Color.primaryGreen, lineWidth: 1)
                            )
                            .font(.system(.subheadline, design: .rounded))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Bottom spacer for tab bar
                    Spacer(minLength: 80)
                }
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingScanStatement) {
            ScanStatementView(preselectedCard: card)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(preselectedCard: card)
        }
        .sheet(isPresented: $showingEditCard) {
            EditCardView(card: card)
        }
    }
}

// Cashback Entry List Item
struct CashbackEntryItem: View {
    let entry: CashbackEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Month and year
            Text(entry.periodMonthYear())
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
            
            // Date range and source
            HStack {
                Text(entry.formattedDateRange())
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(entry.source == .statement ? "From statement" : "Manual entry")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            // Update date
            Text("Updated \(timeAgo(date: entry.dateAdded))")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.textSecondary)
            
            // Amount (right-aligned)
            HStack {
                Spacer()
                Text("₹\(NSDecimalNumber(decimal: entry.amount).stringValue)")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryGreen)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    // Helper to show relative time (e.g., "3 days ago")
    private func timeAgo(date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: date, to: now)
        
        if let days = components.day {
            if days == 0 {
                return "today"
            } else if days == 1 {
                return "yesterday"
            } else {
                return "\(days) days ago"
            }
        }
        
        return "recently"
    }
}

// Helper extension for ordinal numbers (1st, 2nd, 3rd, etc.)
extension Int {
    var ordinal: String {
        let suffix: String
        switch self % 10 {
        case 1 where self % 100 != 11:
            suffix = "st"
        case 2 where self % 100 != 12:
            suffix = "nd"
        case 3 where self % 100 != 13:
            suffix = "rd"
        default:
            suffix = "th"
        }
        return "\(self)\(suffix)"
    }
}

struct CardDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CardDetailView(card: Card.sampleCards[0])
    }
}