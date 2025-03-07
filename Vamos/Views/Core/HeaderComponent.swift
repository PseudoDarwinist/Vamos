import SwiftUI

struct HeaderComponent: View {
    let monthSummary: MonthSummary
    @ObservedObject private var profileStore = UserProfileStore.shared
    @State private var showProfileView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // App logo and title
                Text("bloom")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.primaryGreen)
                
                Spacer()
                
                // User profile access - now using ProfileImageView
                Button(action: {
                    showProfileView = true
                }) {
                    ProfileImageView(image: profileStore.profileImage, size: 50)
                }
            }
            .padding(.bottom, 8)
            
            // Monthly summary display
            VStack(alignment: .leading, spacing: 4) {
                Text("\(monthSummary.monthName) \(monthSummary.yearString)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("₹\(String(format: "%.2f", NSDecimalNumber(decimal: monthSummary.totalSpent).doubleValue))")
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
        .sheet(isPresented: $showProfileView) {
            ProfileView()
        }
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