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
        switch name {
        case "Food & Drink":
            return Category(
                name: "Food & Drink",
                icon: "cup.and.saucer.fill",
                colorHex: "#3CB371" // Medium Sea Green
            )
        case "Transportation":
            return Category(
                name: "Transportation",
                icon: "car.fill",
                colorHex: "#66CDAA" // Medium Aquamarine
            )
        case "Groceries":
            return Category(
                name: "Groceries",
                icon: "cart.fill",
                colorHex: "#2E8B57" // Sea Green
            )
        case "Entertainment":
            return Category(
                name: "Entertainment",
                icon: "tv.fill",
                colorHex: "#5F9EA0" // Cadet Blue
            )
        case "Health":
            return Category(
                name: "Health",
                icon: "heart.fill",
                colorHex: "#FF6B6B" // Light Red
            )
        default:
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