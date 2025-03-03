// File: Vamos/Services/CashbackStore.swift

import Foundation
import Combine

class CashbackStore: ObservableObject {
    static let shared = CashbackStore()
    
    @Published var entries: [CashbackEntry] = []
    
    private let entriesKey = "savedCashbackEntries"
    
        init() {
        loadEntries()
        
        // Remove this block entirely to avoid adding sample entries
        /*
        // Add sample entries if none exist
        if entries.isEmpty {
            #if DEBUG
            // Only add sample entries in debug mode and if there are no entries
            entries = CashbackEntry.sampleEntries
            saveEntries()
            #endif
        }
        */
    }
    
    // MARK: - CRUD Operations
    
    func addEntry(_ entry: CashbackEntry) {
        entries.append(entry)
        saveEntries()
        objectWillChange.send()
    }
    
    func updateEntry(_ updatedEntry: CashbackEntry) {
        if let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) {
            entries[index] = updatedEntry
            saveEntries()
            objectWillChange.send()
        }
    }
    
    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
        objectWillChange.send()
    }
    
    // MARK: - Queries
    
    func getEntriesForCard(cardId: UUID) -> [CashbackEntry] {
        return entries.filter { $0.cardId == cardId }
    }
    
    func getTotalCashback() -> Decimal {
        return entries.reduce(0) { $0 + $1.amount }
    }
    
    func getCashbackForCard(cardId: UUID) -> Decimal {
        return getEntriesForCard(cardId: cardId).reduce(0) { $0 + $1.amount }
    }
    
    func getMonthlyCashback(months: Int = 7) -> [MonthCashbackData] {
        // Get current date and previous months
        let calendar = Calendar.current
        let currentDate = Date()
        
        var monthData: [MonthCashbackData] = []
        
        // Create data for each of the last 'months' months
        for monthOffset in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: currentDate) else {
                continue
            }
            
            // Get start of month
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                continue
            }
            
            // Filter entries for this month
            let monthEntries = entries.filter { entry in
                return entry.periodStart >= startOfMonth && entry.periodStart <= endOfMonth
            }
            
            // Calculate total cashback for month
            let totalCashback = monthEntries.reduce(0) { $0 + $1.amount }
            
            // Format month name (e.g., "Jan")
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let monthName = formatter.string(from: startOfMonth)
            
            monthData.append(MonthCashbackData(month: monthName, amount: totalCashback))
        }
        
        // Return in chronological order (oldest to newest)
        return monthData.reversed()
    }
    
    // MARK: - Persistence
    
    private func saveEntries() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: entriesKey)
            print("📝 Successfully saved \(entries.count) cashback entries")
        } catch {
            print("❌ Failed to save cashback entries: \(error.localizedDescription)")
        }
    }
    
    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else {
            print("📝 No saved cashback entries found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            entries = try decoder.decode([CashbackEntry].self, from: data)
            print("📝 Successfully loaded \(entries.count) cashback entries")
        } catch {
            print("❌ Failed to load cashback entries: \(error.localizedDescription)")
        }
    }
    
    // Clear all saved entries (for testing/debugging)
    func clearAllEntries() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: entriesKey)
        print("🧹 Cleared all saved cashback entries")
        objectWillChange.send()
    }
}

// Helper struct for monthly cashback data (for charts)
struct MonthCashbackData: Identifiable {
    let id = UUID()
    let month: String
    let amount: Decimal
}