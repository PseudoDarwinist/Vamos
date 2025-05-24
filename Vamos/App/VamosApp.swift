import SwiftUI
import CoreData

@main
struct VamosApp: App {
    @State private var selectedTab: Tab = .home
    
    // Initialize UserProfileStore at app startup
    private let profileStore = UserProfileStore.shared
    
    // Initialize PersistenceManager for CoreData
    private let persistenceManager = PersistenceManager.shared
    
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
                    case .creditCard:
                        NavigationView {
                            CardStatementUploadView()
                        }
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    // Save CoreData changes when app goes to background
                    persistenceManager.saveViewContext()
                }
            }
        }
    }
    
    // Scene phase to track app lifecycle
    @Environment(\.scenePhase) private var scenePhase
}