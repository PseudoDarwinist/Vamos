// File: Vamos/Views/Screens/ManualEntryView.swift

import SwiftUI

struct ManualEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var cardStore = CardStore.shared
    @ObservedObject private var cashbackStore = CashbackStore.shared
    
    // Optional preselected card
    var preselectedCard: Card?
    
    // Form fields
    @State private var selectedCardId: UUID?
    @State private var cashbackAmount: String = ""
    @State private var selectedMonth: Date = Date()
    @State private var notes: String = ""
    
    // Date range for the selected month
    private var periodStart: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        return calendar.date(from: components) ?? Date()
    }
    
    private var periodEnd: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = 1
        components.day = -1
        return calendar.date(byAdding: components, to: periodStart) ?? Date()
    }
    
    // Available months for selection (last 12 months)
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        let currentDate = Date()
        
        var months: [Date] = []
        for i in 0..<12 {
            if let date = calendar.date(byAdding: .month, value: -i, to: currentDate) {
                let components = calendar.dateComponents([.year, .month], from: date)
                if let monthDate = calendar.date(from: components) {
                    months.append(monthDate)
                }
            }
        }
        
        return months
    }
    
    // Format month and year (e.g., "February 2025")
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    // Format date range (e.g., "Feb 1 - Feb 28, 2025")
    private func formatDateRange(start: Date, end: Date) -> String {
        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "MMM d"
        
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "MMM d, yyyy"
        
        return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
    }
    
    // Validation
    private var isValid: Bool {
        selectedCardId != nil && 
        !cashbackAmount.isEmpty && 
        (Decimal(string: cashbackAmount) ?? 0) > 0
    }
    
    init(preselectedCard: Card? = nil) {
        self.preselectedCard = preselectedCard
        _selectedCardId = State(initialValue: preselectedCard?.id)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.background
                    .edgesIgnoringSafeArea(.all)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Instruction text
                        Text("Enter the cashback details from your credit card statement")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Card Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Card")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                if cardStore.cards.isEmpty {
                                    // No cards message
                                    HStack {
                                        Text("No cards added yet")
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Button("Add Card") {
                                            // Dismiss this view and show add card view
                                            presentationMode.wrappedValue.dismiss()
                                            // In a real app, you'd need a coordinator pattern to handle this transition
                                        }
                                        .foregroundColor(.primaryGreen)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                } else {
                                    // Card picker
                                    Menu {
                                        ForEach(cardStore.cards) { card in
                                            Button {
                                                selectedCardId = card.id
                                            } label: {
                                                HStack {
                                                    Text("\(card.nickname) (••••\(card.lastFourDigits))")
                                                    if selectedCardId == card.id {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            if let cardId = selectedCardId, let card = cardStore.getCard(id: cardId) {
                                                ZStack {
                                                    Rectangle()
                                                        .fill(card.color)
                                                        .frame(width: 35, height: 25)
                                                        .cornerRadius(3)
                                                    
                                                    Text(card.issuer)
                                                        .font(.system(.caption, design: .rounded))
                                                        .foregroundColor(.white)
                                                }
                                                
                                                Text("\(card.nickname) (••••\(card.lastFourDigits))")
                                                    .foregroundColor(.textPrimary)
                                            } else {
                                                Text("Select a card")
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                    }
                                    .disabled(cardStore.cards.isEmpty)
                                }
                            }
                            
                            // Statement Month
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Statement Month")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                Menu {
                                    ForEach(availableMonths, id: \.self) { month in
                                        Button {
                                            selectedMonth = month
                                        } label: {
                                            HStack {
                                                Text(formatMonthYear(month))
                                                if Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(formatMonthYear(selectedMonth))
                                            .foregroundColor(.textPrimary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                }
                            }
                            
                            // Statement Cycle
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Statement Cycle")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                HStack {
                                    Text(formatDateRange(start: periodStart, end: periodEnd))
                                        .foregroundColor(.textPrimary)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            
                            // Cashback Amount
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Cashback Amount")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                HStack {
                                    Text("₹")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.textPrimary)
                                    
                                    TextField("0.00", text: $cashbackAmount)
                                        .keyboardType(.decimalPad)
                                        .onChange(of: cashbackAmount) { newValue in
                                            // Ensure only valid decimal input
                                            let filtered = newValue.filter { 
                                                "0123456789.".contains($0) 
                                            }
                                            
                                            // Allow only one decimal point
                                            if filtered.filter({ $0 == "." }).count > 1,
                                               let lastIndex = filtered.lastIndex(of: ".") {
                                                var newFiltered = filtered
                                                newFiltered.remove(at: lastIndex)
                                                cashbackAmount = newFiltered
                                            } else {
                                                cashbackAmount = filtered
                                            }
                                        }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            
                            // Notes (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (Optional)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                TextEditor(text: $notes)
                                    .frame(height: 100)
                                    .padding(4)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitle("Add Cashback Manually", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveEntry()
                }
                .disabled(!isValid)
                .opacity(isValid ? 1.0 : 0.5)
            )
        }
    }
    
    private func saveEntry() {
        guard let cardId = selectedCardId,
              let amount = Decimal(string: cashbackAmount) else {
            return
        }
        
        let newEntry = CashbackEntry(
            cardId: cardId,
            periodStart: periodStart,
            periodEnd: periodEnd,
            amount: amount,
            notes: notes.isEmpty ? nil : notes,
            source: .manualEntry
        )
        
        cashbackStore.addEntry(newEntry)
        presentationMode.wrappedValue.dismiss()
    }
}

struct ManualEntryView_Previews: PreviewProvider {
    static var previews: some View {
        ManualEntryView()
    }
}