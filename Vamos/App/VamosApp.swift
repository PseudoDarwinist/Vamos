import SwiftUI

@main
struct VamosApp: App {
    @State private var selectedTab: Tab = .home
    
    // Initialize UserProfileStore at app startup
    private let profileStore = UserProfileStore.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView()
                    case .categories:
                        CategoriesView()
                    case .settings:
                        SettingsView()
                    }
                }
                
                // Tab bar overlay at bottom
                VStack {
                    Spacer()
                    TabBarView(selectedTab: $selectedTab)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            .background(Color.background.edgesIgnoringSafeArea(.all))
        }
    }
}