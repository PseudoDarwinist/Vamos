import SwiftUI

@main
struct VamosApp: App {
    @State private var selectedTab: Tab = .cards
    
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
                    case .cards: // Updated from .history
                        CardsView() // Our new view
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