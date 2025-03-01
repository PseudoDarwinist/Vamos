import SwiftUI

@main
struct VamosApp: App {
    @State private var selectedTab: Tab = .home
    
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
                    case .history:
                        Text("History View")
                            .font(.largeTitle)
                    case .settings:
                        SettingsView() // Make sure this is using your SettingsView
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