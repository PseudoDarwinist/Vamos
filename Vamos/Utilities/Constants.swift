import Foundation
import SwiftUI

struct AppKeys {
    static let geminiApiKey = "AIzaSyD_49Jhf8WZ4irHzaK8KqiEHOw-ILQ3Cow"
}

struct AppColors {
    // App color scheme based on implementation plan
    static let primaryGreen = "#2E8B57" // Sea Green
    static let secondaryGreen = "#3CB371" // Medium Sea Green
    static let background = "#F0F8F5" // Mint Cream
    static let accent = "#66CDAA" // Medium Aquamarine
    static let textPrimary = "#2F4F4F" // Dark Slate Gray
    static let textSecondary = "#5F9EA0" // Cadet Blue
}

struct AppFonts {
    static let heading = Font.system(.headline, design: .rounded)
    static let title = Font.system(.title, design: .rounded).weight(.medium)
    static let body = Font.system(.body, design: .rounded)
    static let subheadline = Font.system(.subheadline, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
}

struct AppDimensions {
    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let iconSize: CGFloat = 24
    static let buttonHeight: CGFloat = 48
    static let cameraButtonSize: CGFloat = 64
}