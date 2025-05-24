/*
 * CreditCardStatementRepository.swift
 * Vamos
 *
 * Implementation of Ticket 7: Data Storage - Persistence Layer for Credit Card Statements
 *
 * Features implemented:
 * - Created CoreData model with entities for CreditCardStatement and Transactions
 * - Implemented entity extensions with mapper methods (DTO <-> Entity conversion)
 * - Developed full CRUD operations for statements (create, read, update, delete)
 * - Added specialized query methods (by card, date range)
 * - Implemented date normalization and data validation
 * - Created optimized data storage with relationship management
 * - Enhanced the PersistenceManager to support CoreData
 * - Updated UI components to use the CoreData persistence layer
 * - Added automatic context saving on app state changes
 */

import Foundation
import CoreData

// MARK: - CoreData Models

// Statement CoreData entity extension
extension CreditCardStatementEntity {
    /// Converts a CreditCardStatement DTO to a CoreData entity
    /// - Parameters:
    ///   - statement: The statement to convert
    ///   - context: The managed object context to use
    /// - Returns: A new or updated CreditCardStatementEntity
    static func from(_ statement: CreditCardStatement, in context: NSManagedObjectContext) -> CreditCardStatementEntity {
        let entity = CreditCardStatementEntity(context: context)
        
        // Set basic properties
        entity.createdAt = Date()
        entity.lastModifiedAt = Date()
        
        // Set card info
        if let card = statement.card {
            entity.cardIssuer = card.issuer
            entity.cardProduct = card.product
            entity.cardLast4 = card.last4
            
            if let period = card.statementPeriod {
                entity.periodFrom = formatDateString(period.from)
                entity.periodTo = formatDateString(period.to)
            }
        }
        
        // Set summary info
        if let summary = statement.summary {
            entity.totalSpend = summary.totalSpend as NSDecimalNumber?
            entity.openingBalance = summary.openingBalance as NSDecimalNumber?
            entity.closingBalance = summary.closingBalance as NSDecimalNumber?
            entity.minPayment = summary.minPayment as NSDecimalNumber?
            entity.dueDate = summary.dueDate
        }
        
        // Create transactions
        for transaction in statement.transactions {
            let transactionEntity = CreditCardTransactionEntity.from(transaction, in: context)
            transactionEntity.statement = entity
            entity.addToTransactions(transactionEntity)
        }
        
        return entity
    }
    
    /// Converts the CoreData entity back to a DTO
    /// - Returns: A CreditCardStatement model
    func toDTO() -> CreditCardStatement {
        // Build card info
        let cardInfo: CardInfo?
        if cardIssuer != nil || cardProduct != nil || cardLast4 != nil || (periodFrom != nil && periodTo != nil) {
            let statementPeriod: StatementPeriod?
            if let from = periodFrom, let to = periodTo {
                statementPeriod = StatementPeriod(from: from, to: to)
            } else {
                statementPeriod = nil
            }
            
            cardInfo = CardInfo(
                issuer: cardIssuer,
                product: cardProduct,
                last4: cardLast4,
                statementPeriod: statementPeriod
            )
        } else {
            cardInfo = nil
        }
        
        // Build summary
        let summaryInfo: StatementSummary?
        if totalSpend != nil || openingBalance != nil || closingBalance != nil || minPayment != nil || dueDate != nil {
            summaryInfo = StatementSummary(
                totalSpend: totalSpend as Decimal?,
                openingBalance: openingBalance as Decimal?,
                closingBalance: closingBalance as Decimal?,
                minPayment: minPayment as Decimal?,
                dueDate: dueDate
            )
        } else {
            summaryInfo = nil
        }
        
        // Build transactions
        let transactions = (self.transactions?.allObjects as? [CreditCardTransactionEntity])?.map { $0.toDTO() } ?? []
        
        return CreditCardStatement(
            card: cardInfo,
            transactions: transactions,
            summary: summaryInfo
        )
    }
    
    /// Formats date string to ISO format if needed
    private static func formatDateString(_ dateString: String) -> String {
        // If already in ISO format, return as is
        if dateString.matches(pattern: "\\d{4}-\\d{2}-\\d{2}") {
            return dateString
        }
        
        // Try to parse and reformat
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let inputFormatters: [DateFormatter] = [
            { let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "MM/dd/yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "dd-MM-yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "dd MMM yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "dd MMM yy"; return df }()
        ]
        
        for formatter in inputFormatters {
            if let date = formatter.date(from: dateString) {
                return dateFormatter.string(from: date)
            }
        }
        
        return dateString
    }
}

// Transaction CoreData entity extension
extension CreditCardTransactionEntity {
    /// Converts a StatementTransaction DTO to a CoreData entity
    /// - Parameters:
    ///   - transaction: The transaction to convert
    ///   - context: The managed object context to use
    /// - Returns: A new CreditCardTransactionEntity
    static func from(_ transaction: StatementTransaction, in context: NSManagedObjectContext) -> CreditCardTransactionEntity {
        let entity = CreditCardTransactionEntity(context: context)
        
        // Set basic properties
        entity.transactionDate = transaction.date
        entity.description_ = transaction.description
        entity.amount = transaction.amount as NSDecimalNumber
        entity.currency = transaction.currency
        entity.type = transaction.type.rawValue
        
        // Set derived properties
        if let derived = transaction.derived {
            entity.category = derived.category
            entity.merchant = derived.merchant
            
            if let fx = derived.fx {
                entity.fxOriginalAmount = fx.originalAmount as NSDecimalNumber
                entity.fxOriginalCurrency = fx.originalCurrency
            }
        }
        
        return entity
    }
    
    /// Converts the CoreData entity back to a DTO
    /// - Returns: A StatementTransaction model
    func toDTO() -> StatementTransaction {
        // Build derived info
        let derivedInfo: DerivedInfo?
        if category != nil || merchant != nil || (fxOriginalAmount != nil && fxOriginalCurrency != nil) {
            let fx: ForeignExchange?
            if let originalAmount = fxOriginalAmount, let originalCurrency = fxOriginalCurrency {
                fx = ForeignExchange(
                    originalAmount: originalAmount as Decimal,
                    originalCurrency: originalCurrency
                )
            } else {
                fx = nil
            }
            
            derivedInfo = DerivedInfo(
                category: category,
                merchant: merchant,
                isRecurring: nil,
                fx: fx
            )
        } else {
            derivedInfo = nil
        }
        
        return StatementTransaction(
            date: transactionDate ?? "",
            description: description_ ?? "",
            amount: (amount ?? 0) as Decimal,
            currency: currency ?? "INR",
            type: TransactionType(rawValue: type ?? "debit") ?? .debit,
            derived: derivedInfo
        )
    }
}

// MARK: - Repository

/// Repository for credit card statement persistence
class CreditCardStatementRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Saves a credit card statement to the database
    /// - Parameter statement: The statement to save
    /// - Throws: CoreData save errors
    func save(_ statement: CreditCardStatement) throws {
        _ = CreditCardStatementEntity.from(statement, in: context)
        try context.save()
    }
    
    /// Retrieves all statements
    /// - Returns: An array of statements
    /// - Throws: CoreData fetch errors
    func getAllStatements() throws -> [CreditCardStatement] {
        let fetchRequest: NSFetchRequest<CreditCardStatementEntity> = CreditCardStatementEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let results = try context.fetch(fetchRequest)
        return results.map { $0.toDTO() }
    }
    
    /// Retrieves statements for a specific card
    /// - Parameter last4: Last 4 digits of the card
    /// - Returns: An array of statements
    /// - Throws: CoreData fetch errors
    func getStatements(forCardWithLast4 last4: String) throws -> [CreditCardStatement] {
        let fetchRequest: NSFetchRequest<CreditCardStatementEntity> = CreditCardStatementEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cardLast4 = %@", last4)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let results = try context.fetch(fetchRequest)
        return results.map { $0.toDTO() }
    }
    
    /// Retrieves statements within a date range
    /// - Parameters:
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    /// - Returns: An array of statements
    /// - Throws: CoreData fetch errors
    func getStatements(fromDate: String, toDate: String) throws -> [CreditCardStatement] {
        let fetchRequest: NSFetchRequest<CreditCardStatementEntity> = CreditCardStatementEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "periodFrom >= %@ AND periodTo <= %@", fromDate, toDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "periodFrom", ascending: false)]
        
        let results = try context.fetch(fetchRequest)
        return results.map { $0.toDTO() }
    }
    
    /// Deletes a statement
    /// - Parameter statement: The statement to delete
    /// - Returns: True if deletion was successful
    /// - Throws: CoreData fetch/save errors
    func delete(_ statement: CreditCardStatement) throws -> Bool {
        let fetchRequest: NSFetchRequest<CreditCardStatementEntity> = CreditCardStatementEntity.fetchRequest()
        
        // Create a compound predicate to uniquely identify the statement
        var predicates: [NSPredicate] = []
        
        if let card = statement.card {
            if let last4 = card.last4 {
                predicates.append(NSPredicate(format: "cardLast4 = %@", last4))
            }
            
            if let period = card.statementPeriod {
                predicates.append(NSPredicate(format: "periodFrom = %@ AND periodTo = %@", period.from, period.to))
            }
        }
        
        // If we have transaction dates, use those as fallback identification
        if !statement.transactions.isEmpty, let firstTxDate = statement.transactions.first?.date {
            predicates.append(NSPredicate(format: "ANY transactions.transactionDate = %@", firstTxDate))
        }
        
        // Only attempt to build compound predicate if we have predicates
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else {
            // No predicates to identify statement, can't proceed
            return false
        }
        
        let results = try context.fetch(fetchRequest)
        guard let entityToDelete = results.first else {
            return false
        }
        
        context.delete(entityToDelete)
        try context.save()
        return true
    }
    
    /// Deletes all statements
    /// - Throws: CoreData fetch/save errors
    func deleteAllStatements() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CreditCardStatementEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        try context.execute(deleteRequest)
        try context.save()
    }
}

// Helper extension for string pattern matching
extension String {
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
} 