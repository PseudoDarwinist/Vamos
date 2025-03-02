import SwiftUI

struct TransactionEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var transactionStore = TransactionStore.shared
    
    // Transaction properties
    @State private var merchantName: String
    @State private var aggregatorName: String
    @State private var amount: String
    @State private var date: Date
    @State private var selectedCategory: Category
    @State private var notes: String
    
    // Original transaction ID (in case of editing)
    private var transactionId: UUID?
    
    // Known aggregators for selection
    private let knownAggregators = ["None", "Swiggy", "Zomato", "Uber Eats", "Amazon", "Flipkart"]
    
    // Available categories
    private let availableCategories = Category.sampleCategories
    
    // Initialize with a new empty transaction
    init() {
        // Simple initializations without complex expressions
        _merchantName = State(initialValue: "")
        _aggregatorName = State(initialValue: "None")
        _amount = State(initialValue: "")
        _date = State(initialValue: Date())
        
        // Create category first, then use it
        let foodCategory = Category.sample(name: "Food & Dining")
        _selectedCategory = State(initialValue: foodCategory)
        
        _notes = State(initialValue: "")
        transactionId = nil
    }
    
    // Initialize with an existing transaction for editing
    init(transaction: Transaction) {
        // Break down complex expressions
        let merchant = transaction.merchant
        let aggregator = transaction.aggregator ?? "None"
        
        // Convert Decimal to string in steps
        let decimalNumber = NSDecimalNumber(decimal: transaction.amount)
        let amountString = decimalNumber.stringValue
        
        let transactionDate = transaction.date
        let category = transaction.category
        let transactionNotes = transaction.notes ?? ""
        
        // Assign to state variables
        _merchantName = State(initialValue: merchant)
        _aggregatorName = State(initialValue: aggregator)
        _amount = State(initialValue: amountString)
        _date = State(initialValue: transactionDate)
        _selectedCategory = State(initialValue: category)
        _notes = State(initialValue: transactionNotes)
        
        // Set transaction ID
        transactionId = transaction.id
    }
    
    // Initialize with partial data from scanned receipt
    init(merchantName: String, amount: Decimal, date: Date, category: Category) {
        // Break down complex expressions
        let merchant = merchantName
        
        // Convert Decimal to string in steps
        let decimalNumber = NSDecimalNumber(decimal: amount)
        let amountString = decimalNumber.stringValue
        
        let transactionDate = date
        
        // Assign to state variables
        _merchantName = State(initialValue: merchant)
        _aggregatorName = State(initialValue: "None")
        _amount = State(initialValue: amountString)
        _date = State(initialValue: transactionDate)
        _selectedCategory = State(initialValue: category)
        _notes = State(initialValue: "")
        
        // No transaction ID for new transactions
        transactionId = nil
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
                        // Title
                        Text(transactionId == nil ? "Add Transaction" : "Edit Transaction")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Form fields
                        VStack(spacing: 16) {
                            // Merchant name field
                            FormField(title: "Merchant", placeholder: "e.g. KFC, Starbucks") {
                                TextField("Merchant name", text: $merchantName)
                                    .font(.system(.body, design: .rounded))
                            }
                            
                            // Aggregator selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Food Delivery Platform")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                Picker("Aggregator", selection: $aggregatorName) {
                                    ForEach(knownAggregators, id: \.self) { aggregator in
                                        Text(aggregator)
                                            .tag(aggregator == "None" ? "None" : aggregator)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            
                            // Amount field
                            FormField(title: "Amount (₹)", placeholder: "0.00") {
                                TextField("Amount", text: $amount)
                                    .font(.system(.body, design: .rounded))
                                    .keyboardType(.decimalPad)
                            }
                            
                            // Date field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .labelsHidden()
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            
                            // Category selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                // Use a simple list instead of a complex picker
                                Menu {
                                    ForEach(availableCategories) { category in
                                        Button(action: {
                                            selectedCategory = category
                                        }) {
                                            HStack {
                                                Image(systemName: category.icon)
                                                    .foregroundColor(category.color)
                                                Text(category.name)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: selectedCategory.icon)
                                            .foregroundColor(selectedCategory.color)
                                        Text(selectedCategory.name)
                                            .foregroundColor(.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.textSecondary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                                }
                            }
                            
                            // Notes field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (Optional)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                TextEditor(text: $notes)
                                    .font(.system(.body, design: .rounded))
                                    .padding()
                                    .frame(height: 100)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                        }
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // Save button
                        Button(action: saveTransaction) {
                            Text("Save Transaction")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primaryGreen)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                
                // Navigation bar with close button
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .padding(8)
                                .background(Color.secondaryGreen.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // Save the transaction
    private func saveTransaction() {
        // Validate inputs
        guard !merchantName.isEmpty, let amountDecimal = Decimal(string: amount) else {
            // Show an error (in a real app, you'd use an alert)
            print("Invalid inputs")
            return
        }
        
        // Process aggregator name
        let finalAggregator = aggregatorName == "None" ? nil : aggregatorName
        
        // Create the transaction
        let transaction = Transaction(
            id: transactionId ?? UUID(),
            amount: amountDecimal,
            date: date,
            merchant: merchantName,
            aggregator: finalAggregator,
            category: selectedCategory,
            sourceType: .manual,
            notes: notes.isEmpty ? nil : notes
        )
        
        // Add to store (this will replace if ID exists)
        transactionStore.addTransaction(transaction)
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
}

// Form field component
struct FormField<Content: View>: View {
    let title: String
    let placeholder: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.textSecondary)
            
            content()
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                .placeholder(when: placeholder != "") {
                    Text(placeholder)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.leading, 4)
                }
        }
    }
}

// Placeholder extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct TransactionEditView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMerchant = "KFC"
        let sampleAmount = Decimal(123.45)
        let sampleDate = Date()
        let sampleCategory = Category.sample(name: "Food & Dining")
        
        return TransactionEditView(
            merchantName: sampleMerchant, 
            amount: sampleAmount, 
            date: sampleDate, 
            category: sampleCategory
        )
    }
}