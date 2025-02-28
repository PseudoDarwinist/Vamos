import SwiftUI

struct TransactionItem: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(transaction.category.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(transaction.category.color)
            }
            
            // Merchant and date
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text(transaction.date.relativeDescription())
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Amount and category
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount).doubleValue))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text(transaction.category.name)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

struct TransactionListSection: View {
    let title: String
    let transactions: [Transaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            ForEach(transactions) { transaction in
                TransactionItem(transaction: transaction)
                    .padding(.horizontal, 16)
            }
        }
    }
}

struct TransactionItem_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TransactionItem(transaction: Transaction.sampleTransactions[0])
            TransactionItem(transaction: Transaction.sampleTransactions[1])
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.background)
    }
}