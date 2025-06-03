import Foundation

/// Post-processes credit card statement data from AI
class StatementPostProcessor {
    
    /// Process the raw statement data from AI
    /// - Parameter statement: The raw statement data
    /// - Returns: The processed statement
    func process(_ statement: CreditCardStatement) -> CreditCardStatement {
        // Create a mutable copy of the statement
        var processedStatement = statement
        
        // Ensure all transactions have proper formatting
        processedStatement.transactions = processTransactions(statement.transactions)
        
        // Apply specific merchant category rules first
        processedStatement.transactions = applyMerchantCategoryRules(processedStatement.transactions)
        
        // Apply UPI category rule (ensure this runs after specific merchant rules)
        processedStatement.transactions = applyUPIRule(processedStatement.transactions)
        
        // Process the summary
        if let summary = processedStatement.summary {
            processedStatement.summary = processSummary(summary)
                } else {
            // Generate a summary if none exists
            processedStatement.summary = generateSummary(from: processedStatement.transactions)
        }
        
        // Ensure statement period is ISO format
        if let statementPeriod = processedStatement.card?.statementPeriod {
            processedStatement.card?.statementPeriod = normalizeStatementPeriod(statementPeriod)
        }
        
        return processedStatement
    }
    
    /// Process transactions for consistency
    /// - Parameter transactions: Array of transactions
    /// - Returns: Processed transactions
    private func processTransactions(_ transactions: [StatementTransaction]) -> [StatementTransaction] {
        return transactions.map { transaction in
            var processedTransaction = transaction
            
            // Normalize date format to ISO (YYYY-MM-DD)
            processedTransaction.date = normalizeDate(transaction.date)
            
            // Ensure description is properly formatted
            processedTransaction.description = cleanDescription(transaction.description)
            
            // Default currency to INR if missing
            if processedTransaction.currency.isEmpty {
                processedTransaction.currency = "INR"
            }
            
            // Ensure derived info is populated
            if processedTransaction.derived == nil {
                processedTransaction.derived = DerivedInfo()
            }
            
            return processedTransaction
        }
    }
    
    /// Apply specific merchant-to-category mappings
    private func applyMerchantCategoryRules(_ transactions: [StatementTransaction]) -> [StatementTransaction] {
        var updatedTransactions = transactions
        for i in 0..<updatedTransactions.count {
            let description = updatedTransactions[i].description.lowercased()
            
            // Fuel Category Rule
            if description.contains("bharat petroleum") || description.contains("bpcl") || description.contains("indian oil") || description.contains("iocl") || description.contains("hpcl") || description.contains("hindustan petroleum") || description.contains("shell") || description.contains("reliance petroleum") {
                if updatedTransactions[i].derived == nil {
                    updatedTransactions[i].derived = DerivedInfo()
                }
                updatedTransactions[i].derived?.category = "Fuel"
            }
            // Check for Swiggy Instamart first (Groceries) before general Swiggy (Food)
            else if description.contains("swiggy") && description.contains("instamart") {
                if updatedTransactions[i].derived == nil {
                    updatedTransactions[i].derived = DerivedInfo()
                }
                updatedTransactions[i].derived?.category = "Groceries"
            }
            // General Swiggy and other food delivery (Food & Dining)
            else if description.contains("swiggy") || description.contains("zomato") || description.contains("dominos") || description.contains("kfc") || description.contains("mcdonalds") || description.contains("pizzahut") || description.contains("burger king") {
                if updatedTransactions[i].derived == nil {
                    updatedTransactions[i].derived = DerivedInfo()
                }
                updatedTransactions[i].derived?.category = "Food & Dining"
            }
            // Groceries category (including other Instamart mentions)
            else if description.contains("bigbasket") || description.contains("grofers") || description.contains("blinkit") || description.contains("zepto") || description.contains("dmart") || description.contains("reliance fresh") || description.contains("instamart") {
                if updatedTransactions[i].derived == nil {
                    updatedTransactions[i].derived = DerivedInfo()
                }
                updatedTransactions[i].derived?.category = "Groceries"
            }
            // ... add more rules as needed
        }
        return updatedTransactions
    }
    
    /// Apply UPI category rule
    private func applyUPIRule(_ transactions: [StatementTransaction]) -> [StatementTransaction] {
        var updatedTransactions = transactions
        for i in 0..<updatedTransactions.count {
            // Only apply UPI rule if a more specific category hasn't already been set
            if (updatedTransactions[i].derived?.category == nil || updatedTransactions[i].derived?.category?.isEmpty == true || updatedTransactions[i].derived?.category == "Other") &&
               (updatedTransactions[i].description.lowercased().contains("upi") ||
                updatedTransactions[i].description.lowercased().contains("vpa") ||
                updatedTransactions[i].description.lowercased().contains("@ok")) {
                if updatedTransactions[i].derived == nil {
                    updatedTransactions[i].derived = DerivedInfo()
                }
                updatedTransactions[i].derived?.category = "UPI"
            }
        }
        return updatedTransactions
    }
    
    /// Process the summary data
    /// - Parameter summary: Original summary
    /// - Returns: Processed summary
    private func processSummary(_ summary: StatementSummary) -> StatementSummary {
        var processedSummary = summary
        
        // Ensure all amounts are positive
        if let totalSpend = processedSummary.totalSpend {
            processedSummary.totalSpend = abs(totalSpend)
        }
        
        if let openingBalance = processedSummary.openingBalance {
            processedSummary.openingBalance = abs(openingBalance)
        }
        
        if let closingBalance = processedSummary.closingBalance {
            processedSummary.closingBalance = abs(closingBalance)
        }
        
        if let minPayment = processedSummary.minPayment {
            processedSummary.minPayment = abs(minPayment)
        }
        
        // Normalize due date if present
        if let dueDate = processedSummary.dueDate {
            processedSummary.dueDate = normalizeDate(dueDate)
        }
        
        return processedSummary
    }
    
    /// Generate a summary from transactions if none exists
    /// - Parameter transactions: Array of transactions
    /// - Returns: Generated summary
    private func generateSummary(from transactions: [StatementTransaction]) -> StatementSummary {
        // Calculate total spends and credits
        let totalSpend = transactions
            .filter { $0.type == .debit }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        let totalCredits = transactions
            .filter { $0.type == .credit }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        // Create a new summary
        return StatementSummary(
            totalSpend: totalSpend,
            openingBalance: nil,
            closingBalance: nil,
            minPayment: nil,
            dueDate: nil
        )
    }
    
    /// Normalize date format to ISO (YYYY-MM-DD)
    /// - Parameter dateString: Date string in any format
    /// - Returns: ISO formatted date string
    private func normalizeDate(_ dateString: String) -> String {
        // If already in ISO format, return as is
        if privateMatches(pattern: "\\d{4}-\\d{2}-\\d{2}", in: dateString) {
            return dateString
        }
        
        // Define date formatters for common formats
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"
        
        let inputFormatters: [DateFormatter] = [
            { let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "MM/dd/yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "dd-MM-yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "MM-dd-yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "dd MMM yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "dd MMM yy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "d MMM yyyy"; return df }(),
            { let df = DateFormatter(); df.dateFormat = "d MMM yy"; return df }()
        ]
        
        // Try to parse with each formatter
            for formatter in inputFormatters {
            if let date = formatter.date(from: dateString) {
                return outputFormatter.string(from: date)
            }
        }
        
        // If all else fails, try to extract year, month, day using regex
        if let (year, month, day) = extractDateComponents(from: dateString) {
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
        
        // Return the original string if parsing fails
        return dateString
    }
    
    /// Extract date components from a string
    /// - Parameter dateString: Date string
    /// - Returns: Tuple of (year, month, day) if successful
    private func extractDateComponents(from dateString: String) -> (Int, Int, Int)? {
        // Extract numbers from the string
        let numbers = dateString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
            .compactMap { Int($0) }
        
        // Check for month name
        let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let lowercasedDate = dateString.lowercased()
        
        var monthNumber: Int?
        for (index, name) in monthNames.enumerated() {
            if lowercasedDate.contains(name) {
                monthNumber = index + 1
                break
            }
        }
        
        // Try to extract components based on different patterns
        if numbers.count >= 3 {
            // Assume DD MM YY/YYYY pattern
            var year = numbers[2]
            let day = numbers[0]
            let month = numbers[1]
            
            // Adjust year if necessary (YY -> YYYY)
            if year < 100 {
                year += 2000
            }
            
            return (year, month, day)
        } else if numbers.count >= 2 && monthNumber != nil {
            // DD MMM YY/YYYY pattern
            var year = numbers[1]
            let day = numbers[0]
            
            // Adjust year if necessary (YY -> YYYY)
            if year < 100 {
                year += 2000
            }
            
            return (year, monthNumber!, day)
        }
        
        return nil
    }
    
    /// Clean and standardize transaction description
    /// - Parameter description: Original description
    /// - Returns: Cleaned description
    private func cleanDescription(_ description: String) -> String {
        // Trim whitespace
        var cleaned = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Replace multiple spaces with a single space
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Remove special characters that might cause issues
        cleaned = cleaned.replacingOccurrences(of: #"[^\w\s\-.,/]"#, with: "", options: .regularExpression)
        
        return cleaned
    }
    
    /// Normalize statement period to ISO format
    /// - Parameter period: Original statement period
    /// - Returns: Normalized statement period
    private func normalizeStatementPeriod(_ period: StatementPeriod) -> StatementPeriod {
        return StatementPeriod(
            from: normalizeDate(period.from),
            to: normalizeDate(period.to)
        )
    }
    
    /// Private method to check if a string matches a regex pattern
    /// - Parameters:
    ///   - pattern: Regex pattern to match
    ///   - string: String to check
    /// - Returns: True if string matches pattern
    private func privateMatches(pattern: String, in string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
} 