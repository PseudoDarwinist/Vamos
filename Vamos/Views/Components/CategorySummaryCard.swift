import SwiftUI

// Category summary card - shared component
struct CategorySummaryCard: View {
    let category: Category
    let totalSpent: Decimal
    let transactionCount: Int
    let merchantName: String?
    
    // Initialize with default nil merchant name
    init(category: Category, totalSpent: Decimal, transactionCount: Int, merchantName: String? = nil) {
        self.category = category
        self.totalSpent = totalSpent
        self.transactionCount = transactionCount
        self.merchantName = merchantName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(category.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchantName != nil ? "Total Spent at \(merchantName!)" : "Total Spent")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.textSecondary)
                    
                    Text("₹\(NSDecimalNumber(decimal: totalSpent).stringValue)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("\(transactionCount) transaction\(transactionCount != 1 ? "s" : "")")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
} 