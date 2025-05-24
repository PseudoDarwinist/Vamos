import Foundation

/// Handles text preprocessing and cleaning for OCR text
class TextProcessor {
    /// Cleans and formats OCR text for optimal AI processing
    /// - Parameter pageTexts: Array of text strings, one per page
    /// - Returns: Single cleaned text string with page markers
    func cleanAndFormatText(pageTexts: [String]) -> String {
        print("📝 TextProcessor: Processing \(pageTexts.count) pages of OCR text")
        
        // Improved page processing
        let processedPages = pageTexts.enumerated().map { index, text in
            let pageNumber = index + 1
            
            // Process this page's text to identify and preserve tables
            let processedText = detectAndPreserveTables(in: text)
            
            if index > 0 {
                return "\n===PAGE \(pageNumber)===\n\(processedText)"
            }
            return "===PAGE \(pageNumber)===\n\(processedText)"
        }
        
        // Join processed pages
        let joinedText = processedPages.joined()
        
        // Apply general cleaning rules
        let cleanedText = applyCleaningRules(to: joinedText)
        
        print("✅ TextProcessor: Completed text processing")
        return cleanedText
    }
    
    /// Detects and preserves table structures in text
    /// - Parameter text: Raw OCR text potentially containing tables
    /// - Returns: Processed text with table structures preserved
    private func detectAndPreserveTables(in text: String) -> String {
        // Split text into lines
        var lines = text.components(separatedBy: .newlines)
        
        // Look for potential transaction table indicators
        let tableHeaders = [
            "date", "transaction", "description", "amount", "balance", "dr", "cr",
            "debit", "credit", "upi", "payment", "particulars", "details"
        ]
        
        // Track where tables begin and end
        var tableStartIndex: Int? = nil
        var inTable = false
        var processedLines = [String]()
        
        for (index, line) in lines.enumerated() {
            let lowercaseLine = line.lowercased()
            
            // Check if this line looks like a table header
            let isTableHeader = tableHeaders.count { lowercaseLine.contains($0) } >= 2
            
            // Check if this line looks like a transaction line (date pattern + amount pattern)
            let hasDatePattern = lowercaseLine.range(of: #"\d{1,2}[/\- ][a-z]{3}[/\- ]\d{2,4}|\d{1,2}[/\- ]\d{1,2}[/\- ]\d{2,4}"#, options: .regularExpression) != nil
            let hasAmountPattern = lowercaseLine.range(of: #"\d+,?\d*\.\d+|\d+,\d+"#, options: .regularExpression) != nil
            let isTransactionLine = hasDatePattern && hasAmountPattern
            
            // Table start detection
            if isTableHeader && !inTable {
                tableStartIndex = index
                inTable = true
                processedLines.append("__TABLE_START__")
                processedLines.append(line)
            }
            // Within a table
            else if inTable {
                // Check if this might be the end of the table (empty line or no numbers)
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                   !lowercaseLine.contains(where: { $0.isNumber }) {
                    // Only consider it the end of the table if we've had at least 3 lines (header + 2+ rows)
                    if processedLines.count > tableStartIndex! + 3 {
                        inTable = false
                        processedLines.append("__TABLE_END__")
                        processedLines.append(line)
                    } else {
                        // Not enough rows to be a table, likely just a false positive
                        processedLines.append(line)
                    }
                } else {
                    // Within table content - preserve exact spacing for tabular data
                    processedLines.append(line)
                }
            }
            // Transaction line without table header (add table markers around it)
            else if isTransactionLine && !inTable {
                processedLines.append("__TABLE_START__")
                processedLines.append(line)
                
                // Look ahead to see if next lines are also transaction lines
                var transactionLinesCount = 1
                for i in (index + 1)..<min(index + 10, lines.count) {
                    let nextLine = lines[i].lowercased()
                    let hasNextDatePattern = nextLine.range(of: #"\d{1,2}[/\- ][a-z]{3}[/\- ]\d{2,4}|\d{1,2}[/\- ]\d{1,2}[/\- ]\d{2,4}"#, options: .regularExpression) != nil
                    let hasNextAmountPattern = nextLine.range(of: #"\d+,?\d*\.\d+|\d+,\d+"#, options: .regularExpression) != nil
                    
                    if hasNextDatePattern && hasNextAmountPattern {
                        transactionLinesCount += 1
                    } else {
                        break
                    }
                }
                
                if transactionLinesCount > 1 {
                    inTable = true
                    tableStartIndex = index
                } else {
                    processedLines.append("__TABLE_END__")
                }
            }
            // Normal line
            else {
                processedLines.append(line)
            }
        }
        
        // If we're still in a table at the end, close it
        if inTable {
            processedLines.append("__TABLE_END__")
        }
        
        return processedLines.joined(separator: "\n")
    }
    
    /// Apply text cleaning rules
    /// - Parameter text: Text to clean
    /// - Returns: Cleaned text
    private func applyCleaningRules(to text: String) -> String {
        // Skip replacement of spaces and newlines inside table markers
        var cleanedParts = [String]()
        let tableParts = text.components(separatedBy: "__TABLE_START__")
        
        for (i, part) in tableParts.enumerated() {
            if i == 0 {
                // First part (before any table)
                cleanedParts.append(cleanNonTabularText(part))
            } else {
                // Contains a table section
                let subParts = part.components(separatedBy: "__TABLE_END__")
                if subParts.count > 0 {
                    // The table content itself - preserve spacing and structure
                    let tableContent = subParts[0]
                    cleanedParts.append("__TABLE_START__" + preserveTableStructure(tableContent))
                    
                    // Content after the table end marker
                    if subParts.count > 1 {
                        cleanedParts.append(cleanNonTabularText(subParts[1]))
                    }
                }
            }
        }
        
        return cleanedParts.joined()
            // Remove the table markers now that we're done
            .replacingOccurrences(of: "__TABLE_START__", with: "")
            .replacingOccurrences(of: "__TABLE_END__", with: "")
            // Remove empty lines
            .replacingOccurrences(of: "\n\\s*\n", with: "\n", options: .regularExpression)
    }
    
    /// Clean non-tabular text with standard rules
    /// - Parameter text: Text to clean
    /// - Returns: Cleaned text
    private func cleanNonTabularText(_ text: String) -> String {
        return text
            // Replace multiple spaces with a single space
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            // Join hyphenated words across line breaks
            .replacingOccurrences(of: "-\\s*\n", with: "", options: .regularExpression)
            // Fix common OCR errors for currency symbols
            .replacingOccurrences(of: "Rs\\.", with: "Rs. ", options: .regularExpression)
            .replacingOccurrences(of: "Rs\\s", with: "Rs. ", options: .regularExpression)
            // Clean up CR/DR markers
            .replacingOccurrences(of: "C\\.R\\.", with: "CR", options: .regularExpression)
            .replacingOccurrences(of: "D\\.R\\.", with: "DR", options: .regularExpression)
            // Normalize date formats
            .replacingOccurrences(of: "(\\d{2})/(\\d{2})/(\\d{2,4})", with: "$1-$2-$3", options: .regularExpression)
            // Trim extra whitespace from lines
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")
    }
    
    /// Preserve table structure for tabular content
    /// - Parameter text: Table text
    /// - Returns: Formatted table text
    private func preserveTableStructure(_ text: String) -> String {
        // For table structure, we want to:
        // 1. Fix C/D markers consistently
        // 2. Normalize date formats
        // 3. Preserve spaces between columns
        return text
            // Clean up CR/DR markers
            .replacingOccurrences(of: "C\\.R\\.", with: "CR", options: .regularExpression)
            .replacingOccurrences(of: "D\\.R\\.", with: "DR", options: .regularExpression)
            .replacingOccurrences(of: "\\bC\\b", with: "C", options: .regularExpression)
            .replacingOccurrences(of: "\\bD\\b", with: "D", options: .regularExpression)
            // Normalize date formats
            .replacingOccurrences(of: "(\\d{2})/(\\d{2})/(\\d{2,4})", with: "$1-$2-$3", options: .regularExpression)
    }
    
    /// Extracts statement period using regular expressions (fallback method)
    /// - Parameter text: OCR text to search
    /// - Returns: Optional tuple with from and to dates
    func extractStatementPeriod(from text: String) -> (fromDate: String, toDate: String)? {
        // Try different regex patterns for statement period
        let patterns = [
            "(?i)Statement Period.*?(\\d{1,2}\\s*[A-Za-z]{3}\\s*\\d{2,4}).*?(\\d{1,2}\\s*[A-Za-z]{3}\\s*\\d{2,4})",
            "(?i)Period:.*?(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}).*?(?:to|-).*?(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})",
            "(?i)Statement Date.*?(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    // Extract the date strings
                    if match.numberOfRanges >= 3 {
                        if let fromRange = Range(match.range(at: 1), in: text),
                           let toRange = Range(match.range(at: 2), in: text) {
                            let fromDate = String(text[fromRange])
                            let toDate = String(text[toRange])
                            return (fromDate, toDate)
                        }
                    } else if match.numberOfRanges >= 2 {
                        // For patterns that only have one date (like statement date)
                        if let dateRange = Range(match.range(at: 1), in: text) {
                            let date = String(text[dateRange])
                            return (date, date) // Use same date for both
                        }
                    }
                }
            }
        }
        
        return nil
    }
} 