
import Foundation

// Extension to link transactions with cards
extension Transaction {
    // Stored property keys
    private struct StorageKeys {
        static var cardIdKey = "cardId"
    }
    
    // Get the card ID (if any) associated with this transaction
    var cardId: UUID? {
        get {
            // Use associated object pattern for retroactive property addition
            guard let cardIdString = objc_getAssociatedObject(self, &StorageKeys.cardIdKey) as? String else {
                return nil
            }
            return UUID(uuidString: cardIdString)
        }
        set {
            objc_setAssociatedObject(self, &StorageKeys.cardIdKey, newValue?.uuidString, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
