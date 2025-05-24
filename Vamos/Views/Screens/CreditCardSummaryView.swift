import SwiftUI

/// Credit Card Summary View - Main page-level component
/// Production-ready SwiftUI for iOS 17+, light & dark mode, localisation-ready
struct CreditCardSummaryView: View {
    let statement: CreditCardStatement?
    let rawTransactionCount: Int
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.layoutDirection) var layoutDirection
    @State private var titleVisible = false
    
    var body: some View {
        ZStack {
            // Background with warm cream texture
            Color.adaptiveCreamBG(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 28) {
                    // Main Title with Cabinet Grotesk styling
                    Text("Credit Card Summary")
                        .font(.system(size: 28, weight: .bold, design: .rounded)) // Cabinet Grotesk fallback
                        .tracking(0.2)
                        .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .opacity(titleVisible ? 1 : 0)
                        .offset(y: titleVisible ? 0 : -20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: titleVisible)
                    
                    if let statement = statement {
                        // Category Summary Card with playful styling
                        CategorySummaryCard(statement: statement)
                            .padding(.horizontal, 16)
                        
                        // Transaction List Section with playful styling
                        CreditCardTransactionListSection(statement: statement)
                            .padding(.horizontal, 16)
                        
                        // Accessibility summary for VoiceOver
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilitySummary(for: statement))
                    } else {
                        // Empty state with playful styling
                        EmptyStatementView()
                            .padding(.horizontal, 20)
                    }
                    
                    // Bottom spacer
                    Spacer(minLength: 64)
                }
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("Statement Results")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                titleVisible = true
            }
        }
    }
    
    /// Generate accessibility summary for VoiceOver
    private func accessibilitySummary(for statement: CreditCardStatement) -> String {
        let transactionCount = statement.transactions.count
        let totalSpend = statement.summary?.totalSpend ?? 0
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        
        let amountText = formatter.string(from: totalSpend as NSNumber) ?? "₹\(totalSpend)"
        
        return "Credit card summary shows \(transactionCount) transactions with total spending of \(amountText)"
    }
}

/// Empty state view when no statement is available
struct EmptyStatementView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var emptyStateVisible = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Color.accentUPI.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Statement Data")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(0.2)
                    .foregroundColor(Color.adaptiveTextPrimaryPlayful(for: colorScheme))
                
                Text("Upload a credit card statement to see your spending analysis")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.adaptiveCardStroke(for: colorScheme), lineWidth: 0.75)
                .fill(Color.adaptiveCardFillPlayful(for: colorScheme))
        )
        .opacity(emptyStateVisible ? 1 : 0)
        .offset(y: emptyStateVisible ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                emptyStateVisible = true
            }
        }
    }
}

// MARK: - Layout Direction Aware Components

/// Layout direction aware HStack that flips order for RTL languages
struct LayoutDirectionAwareHStack<Content: View>: View {
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content
    
    @Environment(\.layoutDirection) var layoutDirection
    
    init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            if layoutDirection == .rightToLeft {
                // Reverse the content order for RTL
                content
                    .environment(\.layoutDirection, .rightToLeft)
            } else {
                content
            }
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        CreditCardSummaryView(statement: .mock, rawTransactionCount: 3)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    NavigationView {
        CreditCardSummaryView(statement: .mock, rawTransactionCount: 3)
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty State") {
    NavigationView {
        CreditCardSummaryView(statement: nil, rawTransactionCount: 0)
    }
    .preferredColorScheme(.light)
}

#Preview("RTL Layout") {
    NavigationView {
        CreditCardSummaryView(statement: .mock, rawTransactionCount: 3)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.light)
} 