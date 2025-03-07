import SwiftUI

struct SettingsView: View {
    @ObservedObject private var transactionStore = TransactionStore.shared
    @ObservedObject private var profileStore = UserProfileStore.shared
    @State private var showClearDataAlert = false
    @State private var showProfileView = false
    
    var body: some View {
        ZStack {
            // Background
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                Text("Settings")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .padding(.top)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Profile section
                        Button(action: {
                            showProfileView = true
                        }) {
                            HStack {
                                // Profile image
                                ProfileImageView(image: profileStore.profileImage, size: 60)
                                
                                // User info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profileStore.userName)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.textPrimary)
                                    
                                    Text("Tap to edit profile")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondary)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Settings sections
                        SettingsSectionView(title: "General") {
                            // App Version
                            SettingsRowView(title: "App Version", detail: "1.0.0")
                            
                            // Clear Data
                            Button(action: {
                                showClearDataAlert = true
                            }) {
                                HStack {
                                    Text("Clear All Transaction Data")
                                        .foregroundColor(.red)
                                    Spacer()
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        SettingsSectionView(title: "About") {
                            // App Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bloom - Expense Tracker")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Text("A user-friendly expense tracking app with a nature-inspired UI that uses natural language processing to scan receipts, extract information, and present your financial data in an intuitive way.")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        
                        // Bottom spacer for tab bar
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .alert(isPresented: $showClearDataAlert) {
                Alert(
                    title: Text("Clear All Data"),
                    message: Text("This will permanently delete all your transaction data. Are you sure you want to continue?"),
                    primaryButton: .destructive(Text("Clear Data")) {
                        // Clear all transaction data
                        transactionStore.clearAllTransactions()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showProfileView) {
                ProfileView()
            }
        }
    }
}

// Settings section view
struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.textPrimary)
                .padding(.leading, 4)
            
            content
        }
    }
}

// Settings row view for simple settings
struct SettingsRowView: View {
    let title: String
    let detail: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Text(detail)
                .foregroundColor(.textSecondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}