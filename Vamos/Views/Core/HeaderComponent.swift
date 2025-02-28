import SwiftUI

struct HeaderComponent: View {
    let monthSummary: MonthSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // App logo and title
                Text("bloom")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.primaryGreen)
                
                Spacer()
                
                // User profile access
                Button(action: {
                    // Action for user profile
                }) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.primaryGreen)
                }
            }
            .padding(.bottom, 8)
            
            // Monthly summary display
            VStack(alignment: .leading, spacing: 4) {
                Text("\(monthSummary.monthName) \(monthSummary.yearString)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: monthSummary.totalSpent).doubleValue))")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryGreen)
                
                Text("\(monthSummary.transactionCount) transactions")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(
            ZStack(alignment: .topTrailing) {
                Color.background
                
                // Organic shapes in background
                Circle()
                    .fill(Color.primaryGreen.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .offset(x: 40, y: -30)
                
                Circle()
                    .fill(Color.accent.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .offset(x: -20, y: 40)
            }
        )
        .cornerRadius(16)
    }
}

struct HeaderComponent_Previews: PreviewProvider {
    static var previews: some View {
        HeaderComponent(monthSummary: MonthSummary.sample)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.background)
    }
}