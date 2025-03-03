// File: Vamos/Models/Card.swift

import Foundation
import SwiftUI

struct Card: Identifiable, Codable {
    let id: UUID
    let nickname: String
    let issuer: String
    let lastFourDigits: String
    let statementDay: Int?
    let colorHex: String
    
    // Computed property for SwiftUI Color
    var color: Color {
        Color(hex: colorHex)
    }
    
    init(id: UUID = UUID(), nickname: String, issuer: String, lastFourDigits: String, statementDay: Int? = nil, colorHex: String) {
        self.id = id
        self.nickname = nickname
        self.issuer = issuer
        self.lastFourDigits = lastFourDigits
        self.statementDay = statementDay
        self.colorHex = colorHex
    }
    
    // MARK: - Sample Data
    static var sampleCards: [Card] {
        [
            Card(
                nickname: "HDFC Diner's Black",
                issuer: "HDFC",
                lastFourDigits: "4785",
                statementDay: 28,
                colorHex: "#3CB371"  // Medium Sea Green
            ),
            Card(
                nickname: "ICICI Amazon Pay",
                issuer: "ICICI",
                lastFourDigits: "8922",
                statementDay: 25,
                colorHex: "#4682B4"  // Steel Blue
            )
        ]
    }
}