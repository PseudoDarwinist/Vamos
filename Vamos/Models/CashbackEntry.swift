// File: Vamos/Models/CashbackEntry.swift

import Foundation

struct CashbackEntry: Identifiable, Codable {
    let id: UUID
    let cardId: UUID
    let periodStart: Date
    let periodEnd: Date
    let amount: Decimal
    let categoryBreakdown: [String: Decimal]?
    let notes: String?
    let dateAdded: Date
    let source: CashbackSource
    
    enum CashbackSource: String, Codable {
        case statement
        case manualEntry
    }
    
    init(id: UUID = UUID(), 
         cardId: UUID, 
         periodStart: Date, 
         periodEnd: Date, 
         amount: Decimal, 
         categoryBreakdown: [String: Decimal]? = nil, 
         notes: String? = nil, 
         dateAdded: Date = Date(), 
         source: CashbackSource) {
        self.id = id
        self.cardId = cardId
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.amount = amount
        self.categoryBreakdown = categoryBreakdown
        self.notes = notes
        self.dateAdded = dateAdded
        self.source = source
    }
    
    // MARK: - Helper Methods
    
    // Get month and year string (e.g., "February 2025")
    func periodMonthYear() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: periodStart)
    }
    
    // Format date range string (e.g., "Feb 1 - Feb 28, 2025")
    func formattedDateRange() -> String {
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM d"
        
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "MMM d, yyyy"
        
        return "\(shortFormatter.string(from: periodStart)) - \(endFormatter.string(from: periodEnd))"
    }
    
    // MARK: - Sample Data
    static var sampleEntries: [CashbackEntry] {
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Create sample entries for the last 3 months
        var entries: [CashbackEntry] = []
        
        // Sample cards
        let cards = Card.sampleCards
        
        // For each card, create entries for last 3 months
        for card in cards {
            for monthOffset in 0..<3 {
                // Calculate period dates
                let periodEnd = calendar.date(byAdding: .month, value: -monthOffset, to: currentDate)!
                let periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: periodEnd))!
                
                // Random amount between 200 and 800
                let amount = Decimal(Int.random(in: 200...800))
                
                entries.append(
                    CashbackEntry(
                        cardId: card.id,
                        periodStart: periodStart,
                        periodEnd: calendar.date(byAdding: DateComponents(month: 1, day: -1), to: periodStart)!,
                        amount: amount,
                        categoryBreakdown: nil,
                        notes: nil,
                        dateAdded: calendar.date(byAdding: .day, value: -Int.random(in: 1...10), to: currentDate)!,
                        source: .manualEntry
                    )
                )
            }
        }
        
        return entries
    }
}