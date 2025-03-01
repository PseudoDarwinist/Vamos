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
                        Text("Settings View")
                            .font(.largeTitle)
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