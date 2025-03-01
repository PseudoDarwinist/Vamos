import SwiftUI

struct SpendingStoryCard: View {
    let narrativeSummary: String
    let transactionCount: Int
    
    @State private var queryText: String = ""
    @State private var isQueryMode: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Narrative summary text
            if !isQueryMode {
                Text(narrativeSummary)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineSpacing(4)
                    .padding(.bottom, 8)
                
                // "Ask about your spending" button
                Button(action: {
                    withAnimation {
                        isQueryMode = true
                    }
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(transactionCount > 0 ? Color.primaryGreen : Color.gray))
                        
                        Text("Ask about your spending")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(transactionCount > 0 ? .primaryGreen : .gray)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(transactionCount > 0 ? .primaryGreen : .gray)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.vertical, 8)
                }
                .disabled(transactionCount == 0)
                
                Divider()
                    .background(Color.accent.opacity(0.3))
                
                // Transaction count and explore button
                HStack {
                    Text("\(transactionCount) transactions")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Button(action: {
                        // Action to explore all transactions
                    }) {
                        Text("Explore")
                            .font(.system(.footnote, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.accent)
                    }
                }
            } else {
                // Query mode
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondaryGreen)
                        
                        TextField("Ask a question about your spending", text: $queryText)
                            .font(.system(.body, design: .rounded))
                        
                        if !queryText.isEmpty {
                            Button(action: {
                                queryText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Button(action: {
                            withAnimation {
                                isQueryMode = false
                                queryText = ""
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Process query
                            withAnimation {
                                isQueryMode = false
                                queryText = ""
                            }
                        }) {
                            Text("Ask")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(queryText.isEmpty ? Color.secondaryGreen.opacity(0.5) : Color.secondaryGreen)
                                )
                        }
                        .disabled(queryText.isEmpty)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondaryGreen.opacity(0.1))
        .cornerRadius(16)
    }
}

struct SpendingStoryCard_Previews: PreviewProvider {
    static var previews: some View {
        SpendingStoryCard(
            narrativeSummary: "This month, you've spent most on Food & Drink. Your grocery spending is 15% lower than last month, which means your plant is growing well! 🌱",
            transactionCount: 19
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.background)
    }
}