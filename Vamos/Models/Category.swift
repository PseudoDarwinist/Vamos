import Foundation
import SwiftUI

struct Category: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String // SF Symbol name
    let colorHex: String
    
    // Computed property for SwiftUI Color
    var color: Color {
        Color(hex: colorHex)
    }
    
    init(id: UUID = UUID(), name: String, icon: String, colorHex: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
    
    // Coding keys to handle Color serialization
    enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex
    }
}

// MARK: - Sample Data
extension Category {
        static func sample(name: String) -> Category {
        // Normalize the category name to improve matching
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch normalizedName {
        case "food & dining", "food & drink", "food", "dining", "restaurant", "restaurants":
            return Category(
                name: "Food & Dining",
                icon: "cup.and.saucer.fill",
                colorHex: "#3CB371" // Medium Sea Green
            )
        case "transportation", "transport", "travel":
            return Category(
                name: "Transportation",
                icon: "car.fill",
                colorHex: "#66CDAA" // Medium Aquamarine
            )
        case "groceries", "grocery", "supermarket":
            return Category(
                name: "Groceries",
                icon: "cart.fill",
                colorHex: "#2E8B57" // Sea Green
            )
        case "entertainment", "movies", "music":
            return Category(
                name: "Entertainment",
                icon: "tv.fill",
                colorHex: "#5F9EA0" // Cadet Blue
            )
        case "health", "healthcare", "medical", "fitness":
            return Category(
                name: "Health",
                icon: "heart.fill",
                colorHex: "#FF6B6B" // Light Red
            )
        case "shopping", "retail", "store", "amazon", "online shopping":
            return Category(
                name: "Shopping",
                icon: "bag.fill",
                colorHex: "#4682B4" // Steel Blue
            )
        default:
            // Print debug info for unmatched categories
            print("⚠️ No matching category found for: '\(name)'. Using Miscellaneous.")
            return Category(
                name: "Miscellaneous",
                icon: "square.grid.2x2.fill",
                colorHex: "#2F4F4F" // Dark Slate Gray
            )
        }
    }
    
    static var sampleCategories: [Category] {
        [
            sample(name: "Food & Drink"),
            sample(name: "Transportation"),
            sample(name: "Groceries"),
            sample(name: "Entertainment"),
            sample(name: "Health"),
            sample(name: "Miscellaneous")
        ]
    }
}