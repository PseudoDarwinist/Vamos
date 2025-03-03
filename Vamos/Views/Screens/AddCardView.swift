// File: Vamos/Views/Screens/AddCardView.swift

import SwiftUI

struct AddCardView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var cardStore = CardStore.shared
    
    // Card fields
    @State private var nickname = ""
    @State private var issuer = ""
    @State private var lastFourDigits = ""
    @State private var statementDay: String = ""
    @State private var selectedColor = "#3CB371" // Default color (Primary Green)
    
    // UI states
    @State private var showingIssuerPicker = false
    
    // Available colors for cards
    private let cardColors = [
        "#3CB371", // Medium Sea Green (Primary)
        "#4682B4", // Steel Blue
        "#800080", // Purple
        "#FF6347", // Tomato
        "#FFD700", // Gold
        "#2F4F4F"  // Dark Slate Gray
    ]
    
    // Available bank issuers
    private let bankIssuers = [
        "HDFC", "ICICI", "SBI", "Axis", "Kotak", 
        "HSBC", "Citi", "Standard Chartered", "Other"
    ]
    
    // Validation
    private var isValid: Bool {
        !nickname.isEmpty && 
        !issuer.isEmpty && 
        lastFourDigits.count == 4 && 
        Int(lastFourDigits) != nil &&
        (statementDay.isEmpty || (Int(statementDay) != nil && Int(statementDay)! >= 1 && Int(statementDay)! <= 31))
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
                        // Card Preview
                        ZStack {
                            Rectangle()
                                .fill(Color(hex: selectedColor))
                                .frame(height: 160)
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                // Card nickname
                                Text(nickname.isEmpty ? "Card Name" : nickname)
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
                                    
                                    Text(issuer.isEmpty ? "BANK" : issuer)
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                // Card number
                                Text("•••• •••• •••• \(lastFourDigits.isEmpty ? "••••" : lastFourDigits)")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Card Nickname
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Nickname")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                TextField("e.g. HDFC Diner's Black", text: $nickname)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            
                            // Card Issuer
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Issuer")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                Menu {
                                    ForEach(bankIssuers, id: \.self) { bank in
                                        Button(bank) {
                                            issuer = bank
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(issuer.isEmpty ? "Select bank" : issuer)
                                            .foregroundColor(issuer.isEmpty ? .gray : .textPrimary)
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
                            
                            // Last 4 Digits
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last 4 Digits")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                TextField("e.g. 4785", text: $lastFourDigits)
                                    .keyboardType(.numberPad)
                                    .onChange(of: lastFourDigits) { newValue in
                                        // Restrict to 4 digits
                                        if newValue.count > 4 {
                                            lastFourDigits = String(newValue.prefix(4))
                                        }
                                        // Ensure digits only
                                        lastFourDigits = newValue.filter { "0123456789".contains($0) }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            
                            // Statement Day (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Statement Generation Day (Optional)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                TextField("e.g. 15", text: $statementDay)
                                    .keyboardType(.numberPad)
                                    .onChange(of: statementDay) { newValue in
                                        // Restrict to digits
                                        statementDay = newValue.filter { "0123456789".contains($0) }
                                        
                                        // Ensure valid day (1-31)
                                        if let day = Int(statementDay), day > 31 {
                                            statementDay = "31"
                                        }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            
                            // Card Color
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Color")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                // Color picker
                                HStack(spacing: 12) {
                                    ForEach(cardColors, id: \.self) { colorHex in
                                        Circle()
                                            .fill(Color(hex: colorHex))
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: colorHex == selectedColor ? 3 : 0)
                                            )
                                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            .onTapGesture {
                                                selectedColor = colorHex
                                            }
                                    }
                                }
                                .padding()
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
            .navigationBarTitle("Add New Card", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveCard()
                }
                .disabled(!isValid)
                .opacity(isValid ? 1.0 : 0.5)
            )
        }
    }
    
    private func saveCard() {
        let newCard = Card(
            nickname: nickname,
            issuer: issuer,
            lastFourDigits: lastFourDigits,
            statementDay: statementDay.isEmpty ? nil : Int(statementDay),
            colorHex: selectedColor
        )
        
        cardStore.addCard(newCard)
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddCardView_Previews: PreviewProvider {
    static var previews: some View {
        AddCardView()
    }
}