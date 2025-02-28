import SwiftUI

extension Color {
    // App color scheme based on implementation plan
    static let primaryGreen = Color(hex: "#2E8B57") // Sea Green
    static let secondaryGreen = Color(hex: "#3CB371") // Medium Sea Green
    static let background = Color(hex: "#F0F8F5") // Mint Cream
    static let accent = Color(hex: "#66CDAA") // Medium Aquamarine
    static let textPrimary = Color(hex: "#2F4F4F") // Dark Slate Gray
    static let textSecondary = Color(hex: "#5F9EA0") // Cadet Blue
    
    // Initialize color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Extensions
extension LinearGradient {
    static let greenToTeal = LinearGradient(
        gradient: Gradient(colors: [.primaryGreen, .accent]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}