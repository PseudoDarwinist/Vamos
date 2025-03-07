import SwiftUI

enum Tab {
    case home
    case categories
    case cards // Renamed from history
    case settings
}

struct TabBarView: View {
    @Binding var selectedTab: Tab
    @State private var showScanner: Bool = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                tabButton(title: "", icon: "magnifyingglass", tab: .home)
                
                tabButton(title: "", icon: "leaf", tab: .categories)
                
                // Camera button space
                Spacer()
                    .frame(width: 80)
                
                // Replace the chart.bar icon with creditcard.fill
                tabButton(title: "", icon: "creditcard.fill", tab: .cards) // Updated
                
                tabButton(title: "", icon: "gearshape", tab: .settings)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Color.white
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
            )
            
            // Center camera button
            CameraButton {
                showScanner = true
            }
            .offset(y: -20)
        }
        .sheet(isPresented: $showScanner) {
            ScannerView()
        }
        .onAppear {
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
    }
    
    private func tabButton(title: String, icon: String, tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        
        return Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                // Circle background for icons
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.primaryGreen.opacity(0.2) : Color.background)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .primaryGreen : .textSecondary)
                }
                
                // Optional: if you want to keep the text labels
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10, design: .rounded))
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(isSelected ? .primaryGreen : .textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // Setup notification observers for navigation requests
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToHomeView"),
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = .home
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToCardsView"),
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = .cards
        }
    }
    
    // Remove notification observers
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("NavigateToHomeView"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("NavigateToCardsView"),
            object: nil
        )
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            TabBarView(selectedTab: .constant(.home))
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}