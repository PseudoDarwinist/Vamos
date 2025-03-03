// File: Vamos/Views/Screens/VerifyStatementView.swift

import SwiftUI

struct VerifyStatementView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var cardStore = CardStore.shared
    @ObservedObject private var cashbackStore = CashbackStore.shared
    
    // Data passed from scanner
    let extractedData: OCRService.StatementData
    let statementImage: UIImage
    var preselectedCard: Card?
    
    // Form state
    @State private var selectedCardId: UUID?
    @State private var cashbackAmount: String = ""
    @State private var periodStart: Date = Date()
    @State private var periodEnd: Date = Date()
    @State private var notes: String = ""
    
    // Initialize with extracted data
    init(extractedData: OCRService.StatementData, statementImage: UIImage, preselectedCard: Card? = nil) {
        self.extractedData = extractedData
        self.statementImage = statementImage
        self.preselectedCard = preselectedCard
        
        // Find matching card if card number is extracted
        var matchingCard: Card? = preselectedCard
        if let cardNumber = extractedData.cardNumber, preselectedCard == nil {
            matchingCard = cardStore.cards.first { $0.lastFourDigits == cardNumber }
        }
        
        // Initialize state with extracted values or defaults
        _selectedCardId = State(initialValue: matchingCard?.id)
        
        if let amount = extractedData.cashbackAmount {
            _cashbackAmount = State(initialValue: "\(amount)")
        } else {
            _cashbackAmount = State(initialValue: "")
        }
        
        // Initialize date states with extracted values or defaults
        let startDate = extractedData.periodStart ?? Date()
        let endDate = extractedData.periodEnd ?? Date()
        _periodStart = State(initialValue: startDate)
        _periodEnd = State(initialValue: endDate)
    }
    
    // Validation
    private var isValid: Bool {
        selectedCardId != nil && 
        !cashbackAmount.isEmpty && 
        (Decimal(string: cashbackAmount) ?? 0) > 0
    }
    
    // Format date range (e.g., "Feb 1 - Feb 28, 2025")
    func formatDateRange(start: Date, end: Date) -> String {
        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "MMM d"
        
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "MMM d, yyyy"
        
        return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
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
                        // Success message
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.primaryGreen)
                            
                            Text("Successfully extracted information")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primaryGreen)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primaryGreen.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Statement preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .frame(height: 100)
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Bank name if available
                                    if let bankName = extractedData.bankName {
                                        Text("\(bankName) Bank Statement")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    } else {
                                        Text("Credit Card Statement")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    }
                                    
                                    // Card number if available
                                    if let cardNumber = extractedData.cardNumber {
                                        Text("Card ending in \(cardNumber)")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    }
                                    
                                    // Statement period if available
                                    if extractedData.periodStart != nil && extractedData.periodEnd != nil {
                                        Text(formatDateRange(start: periodStart, end: periodEnd))
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // View original button
                                Button(action: {
                                    // Would show full statement image in a real app
                                }) {
                                    Text("View")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.primaryGreen)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.primaryGreen.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                        
                        // Extracted Information Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Extracted Information")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal)
                            
                            // Card Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                if cardStore.cards.isEmpty {
                                    cardEmptyState
                                } else {
                                    cardPickerView
                                }
                            }
                            .padding(.horizontal)
                            
                            // Statement Period
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Statement Period")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                HStack {
                                    Text(formatDateRange(start: periodStart, end: periodEnd))
                                        .foregroundColor(.textPrimary)
                                    
                                    Spacer()
                                    
                                    // Edit button would go here in a real app
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.primaryGreen.opacity(0.7))
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            .padding(.horizontal)
                            
                            // Cashback Amount
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Cashback Amount")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                if let entries = extractedData.cashbackEntries, entries.count > 1 {
                                    multipleCashbackEntries(entries: entries)
                                } else {
                                    singleCashbackEntry
                                }
                            }
                            .padding(.horizontal)
                            
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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
                                            .padding(1)
                                    )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitle("Verify Statement Details", displayMode: .inline)
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
    
    // MARK: - UI Components
    
    // Empty state for no cards
    var cardEmptyState: some View {
        HStack {
            Text("No cards added yet")
                .foregroundColor(.gray)
            Spacer()
            Button("Add Card") {
                // Would use a coordinator in a real app
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.primaryGreen)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    // Card picker menu
    var cardPickerView: some View {
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
                    HStack {
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
                    }
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
    
    // Single cashback entry UI
    var singleCashbackEntry: some View {
        HStack {
            Text("₹")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.textPrimary)
            
            TextField("0.00", text: $cashbackAmount)
                .keyboardType(.decimalPad)
                .onChange(of: cashbackAmount) { newValue in
                    let filtered = newValue.filter { "0123456789.".contains($0) }
                    
                    if filtered.filter({ $0 == "." }).count > 1,
                       let lastIndex = filtered.lastIndex(of: ".") {
                        var newFiltered = filtered
                        newFiltered.remove(at: lastIndex)
                        cashbackAmount = newFiltered
                    } else {
                        cashbackAmount = filtered
                    }
                }
            
            Spacer()
            
            // Edit icon
            Image(systemName: "pencil")
                .font(.system(size: 14))
                .foregroundColor(.primaryGreen.opacity(0.7))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    // Multiple cashback entries UI
    func multipleCashbackEntries(entries: [Decimal]) -> some View {
        VStack(spacing: 8) {
            // Total amount (editable)
            HStack {
                Text("₹")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                TextField("0.00", text: $cashbackAmount)
                    .keyboardType(.decimalPad)
                    .onChange(of: cashbackAmount) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        
                        if filtered.filter({ $0 == "." }).count > 1,
                           let lastIndex = filtered.lastIndex(of: ".") {
                            var newFiltered = filtered
                            newFiltered.remove(at: lastIndex)
                            cashbackAmount = newFiltered
                        } else {
                            cashbackAmount = filtered
                        }
                    }
                
                Spacer()
                
                Text("Total")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.primaryGreen.opacity(0.7))
                
                // Edit icon
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.primaryGreen.opacity(0.7))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            
            // Individual entries section
            VStack(alignment: .leading, spacing: 8) {
                Text("Individual cashback entries:")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .padding(.leading, 8)
                    .padding(.top, 4)
                
                VStack(spacing: 6) {
                    ForEach(entries.indices, id: \.self) { index in
                        HStack {
                            Text("Entry \(index + 1):")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.textSecondary)
                            
                            Spacer()
                            
                            Text("₹\(NSDecimalNumber(decimal: entries[index]).stringValue)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // Save the cashback entry
    func saveEntry() {
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
            source: .statement
        )
        
        cashbackStore.addEntry(newEntry)
        presentationMode.wrappedValue.dismiss()
    }
}

struct VerifyStatementView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample statement data for preview
        let statementData = OCRService.StatementData()
        let image = UIImage() // Would use a real image in a real app
        
        return VerifyStatementView(
            extractedData: statementData,
            statementImage: image
        )
    }
}