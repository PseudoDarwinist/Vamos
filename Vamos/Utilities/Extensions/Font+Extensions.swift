import SwiftUI

// MARK: - Cabinet Grotesk Font Extensions

extension Font {
    
    // MARK: - Cabinet Grotesk Font Family
    
    static func cabinetGrotesk(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Use the correct font names from the debug output
        let fontName: String
        
        switch weight {
        case .ultraLight:
            fontName = "CabinetGroteskVariable-Bold_Extralight"
        case .thin:
            fontName = "CabinetGroteskVariable-Bold_Thin"
        case .light:
            fontName = "CabinetGroteskVariable-Bold_Light"
        case .regular:
            fontName = "CabinetGroteskVariable-Bold_Regular"
        case .medium:
            fontName = "CabinetGroteskVariable-Bold_Medium"
        case .semibold:
            fontName = "CabinetGroteskVariable-Bold_Medium" // Use Medium for semibold
        case .bold:
            fontName = "CabinetGroteskVariable-Bold_Bold"
        case .heavy:
            fontName = "CabinetGroteskVariable-Bold_Extrabold"
        case .black:
            fontName = "CabinetGroteskVariable-Bold"
        default:
            fontName = "CabinetGroteskVariable-Bold_Regular"
        }
        
        // Try to load the specific font name
        if let customFont = UIFont(name: fontName, size: size) {
            return Font(customFont)
        }
        
        // Fallback to system font if something goes wrong
        return .system(size: size, weight: weight, design: .rounded)
    }
    
    // MARK: - Specific Font Styles for Credit Card Summary (matching the design image)
    
    /// Main title font - "Credit Card Summary"
    static var creditCardTitle: Font {
        cabinetGrotesk(size: 28, weight: .bold)
    }
    
    /// Section headers - "Spending by Category", "Transactions"
    static var sectionHeader: Font {
        cabinetGrotesk(size: 20, weight: .bold)
    }
    
    /// Category labels - "UPI", "Other"
    static var categoryLabel: Font {
        cabinetGrotesk(size: 15, weight: .semibold)
    }
    
    /// Percentage text - "62%", "38%"
    static var percentage: Font {
        cabinetGrotesk(size: 11, weight: .regular)
    }
    
    /// Merchant names - "Swiggy", "INSTMART", "UPI transfer RATI MEHRA"
    static var merchantName: Font {
        cabinetGrotesk(size: 17, weight: .semibold)
    }
    
    /// Amount text - "₹180", "₹720", "₹500"
    static var amount: Font {
        cabinetGrotesk(size: 17, weight: .semibold)
    }
    
    /// Date text - "02 May", "01 May"
    static var transactionDate: Font {
        cabinetGrotesk(size: 11, weight: .medium)
    }
    
    /// UPI badge text
    static var badge: Font {
        cabinetGrotesk(size: 9, weight: .semibold)
    }
}

// MARK: - Helper for Dynamic Font Sizing

extension Font {
    static func cabinetGroteskDynamic(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        cabinetGrotesk(size: size, weight: weight)
    }
} 