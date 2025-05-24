import Foundation
import Combine
import CoreData

class PersistenceManager {
    static let shared = PersistenceManager()
    
    // MARK: - UserDefaults Keys
    private let transactionsKey = "savedTransactions"
    
    // MARK: - CoreData
    private let containerName = "Vamos"
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: containerName)
        
        // Configure migration options
        let description = NSPersistentStoreDescription()
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error loading persistent stores: \(error), \(error.userInfo)")
                // For development, we'll crash on unresolved CoreData errors
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            // Enable data model debug info in development
            #if DEBUG
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.undoManager = nil
            container.viewContext.shouldDeleteInaccessibleFaults = true
            #endif
        }
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // For operations on background threads
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Legacy UserDefaults Methods (maintained for backward compatibility)
    
    // Save transactions to UserDefaults
    func saveTransactions(_ transactions: [Transaction]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(transactions)
            UserDefaults.standard.set(data, forKey: transactionsKey)
            print("📝 Successfully saved \(transactions.count) transactions")
        } catch {
            print("❌ Failed to save transactions: \(error.localizedDescription)")
        }
    }
    
    // Load transactions from UserDefaults
    func loadTransactions() -> [Transaction] {
        guard let data = UserDefaults.standard.data(forKey: transactionsKey) else {
            print("📝 No saved transactions found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let transactions = try decoder.decode([Transaction].self, from: data)
            print("📝 Successfully loaded \(transactions.count) transactions")
            return transactions
        } catch {
            print("❌ Failed to load transactions: \(error.localizedDescription)")
            return []
        }
    }
    
    // Clear all saved transactions (for testing/debugging)
    func clearAllTransactions() {
        UserDefaults.standard.removeObject(forKey: transactionsKey)
        print("🧹 Cleared all saved transactions")
    }
    
    // MARK: - CoreData Utilities
    
    /// Saves changes in the specified context
    /// - Parameter context: The context to save
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
                print("💾 Successfully saved context")
            } catch {
                let nsError = error as NSError
                print("❌ CoreData save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// Saves changes in the main view context
    func saveViewContext() {
        saveContext(viewContext)
    }
    
    // MARK: - Migration Helpers
    
    func migrateStatementSummaryData() {
        let context = newBackgroundContext()
        context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CreditCardStatementEntity")
            
            do {
                let results = try context.fetch(fetchRequest) as? [NSManagedObject] ?? []
                
                for entity in results {
                    // Check if we have old format properties
                    if let totalDebits = entity.value(forKey: "totalDebits") as? NSDecimalNumber,
                       entity.value(forKey: "totalSpend") == nil {
                        
                        // Migrate totalDebits to totalSpend
                        entity.setValue(totalDebits, forKey: "totalSpend")
                        
                        // We could set additional defaults here if needed
                        // entity.setValue(..., forKey: "openingBalance")
                        // entity.setValue(..., forKey: "closingBalance")
                        // entity.setValue(..., forKey: "minPayment")
                        // entity.setValue(..., forKey: "dueDate")
                    }
                }
                
                if context.hasChanges {
                    try context.save()
                    print("Successfully migrated statement summary data")
                }
            } catch {
                print("Failed to migrate statement summary data: \(error)")
            }
        }
    }
}