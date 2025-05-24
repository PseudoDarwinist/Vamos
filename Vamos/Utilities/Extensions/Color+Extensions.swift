import SwiftUI

extension Color {
    // App color scheme based on implementation plan
    static let primaryGreen = Color(hex: "#2E8B57") // Sea Green
    static let secondaryGreen = Color(hex: "#3CB371") // Medium Sea Green
    static let background = Color(hex: "#F0F8F5") // Mint Cream
    static let secondaryBackground = Color(hex: "#E0F0EB") // Light Mint
    static let accent = Color(hex: "#66CDAA") // Medium Aquamarine
    static let textPrimary = Color(hex: "#2F4F4F") // Dark Slate Gray
    static let textSecondary = Color(hex: "#5F9EA0") // Cadet Blue
    
    // MARK: - Credit Card Summary Design Tokens
    
    // Canvas and backgrounds
    static let canvasBG = Color(hex: "#FFF7E8") // Light warm canvas
    static let canvasBGDark = Color(hex: "#121212") // Dark canvas
    static let cardFill = Color(hex: "#FFFCEE") // Card background light
    static let cardFillDark = Color(hex: "#1E1E1E") // Card background dark
    
    // Strokes and borders
    static let stroke = Color(hex: "#063852").opacity(0.15) // Light stroke
    static let strokeDark = Color(hex: "#A9CCE3").opacity(0.30) // Dark stroke
    
    // Transaction amount colors
    static let debitRed = Color(hex: "#E6533C") // Debit amount light
    static let debitRedDark = Color(hex: "#FF6B5A") // Debit amount dark
    static let creditGreen = Color(hex: "#11835D") // Credit amount light  
    static let creditGreenDark = Color(hex: "#34C38B") // Credit amount dark
    
    // Accent colors for charts and highlights
    static let accentBlue = Color(hex: "#5C9BD1") // Pie slice, progress light
    static let accentBlueDark = Color(hex: "#73B3FF") // Pie slice, progress dark
    
    // Environment-aware computed properties
    static func adaptiveCanvasBG(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? canvasBGDark : canvasBG
    }
    
    static func adaptiveCardFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardFillDark : cardFill
    }
    
    static func adaptiveStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? strokeDark : stroke
    }
    
    static func adaptiveDebitRed(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? debitRedDark : debitRed
    }
    
    static func adaptiveCreditGreen(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? creditGreenDark : creditGreen
    }
    
    static func adaptiveAccentBlue(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? accentBlueDark : accentBlue
    }
    
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
    
    // MARK: - Playful Design Tokens (New)
    
    // Main backgrounds - warm and inviting
    static let creamBackground = Color(hex: "#FFF8E8") // Light cream
    static let creamBackgroundDark = Color(hex: "#1C1C1C") // Dark warm
    
    // Card styling - softer than pure white
    static let cardFillPlayful = Color(hex: "#FFFCEE") // Warmer card background
    static let cardFillPlayfulDark = Color(hex: "#2A2A2A") // Dark card
    
    // Strokes - hand-sketched feel
    static let cardStroke = Color(hex: "#E4E1D6") // Light sketch stroke
    static let cardStrokeDark = Color(hex: "#2A2A2A") // Dark sketch stroke
    
    // Text - warmer than pure black
    static let textPrimaryPlayful = Color(hex: "#17323F") // Deep teal-black
    static let textPrimaryPlayfulDark = Color(hex: "#F6F6F6") // Warm white
    
    // Category icon colors - vibrant and friendly
    static let accentFood = Color(hex: "#FFB14E") // Warm orange
    static let accentGrocery = Color(hex: "#54B68E") // Fresh green
    static let accentUPI = Color(hex: "#7DA9F7") // Soft blue
    static let accentFuel = Color(hex: "#D86E4D") // Warm red
    static let accentOther = Color(hex: "#9B9B9B") // Neutral gray
    
    // Accent red for amounts
    static let accentRed = Color(hex: "#E44F43") // Playful red
    
    // Environment-aware playful colors
    static func adaptiveCreamBG(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? creamBackgroundDark : creamBackground
    }
    
    static func adaptiveCardFillPlayful(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardFillPlayfulDark : cardFillPlayful
    }
    
    static func adaptiveCardStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardStrokeDark : cardStroke
    }
    
    static func adaptiveTextPrimaryPlayful(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textPrimaryPlayfulDark : textPrimaryPlayful
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

// MARK: - View Modifiers for Credit Card Summary

extension View {
    /// Apply the playful card style for Credit Card Summary components
    func creditCardStyle() -> some View {
        self
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.adaptiveCardStroke(for: .light), lineWidth: 0.75)
                    .fill(Color.adaptiveCardFillPlayful(for: .light))
            }
    }
}