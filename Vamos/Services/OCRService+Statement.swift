// File: Vamos/Services/OCRService+Statement.swift

import Foundation
import UIKit
import Combine

// Extension to OCRService for processing credit card statements
extension OCRService {
    // Process statement image
    func processStatement(image: UIImage) -> AnyPublisher<StatementData, Error> {
        print("🟢 Starting statement processing")
        
        return processReceiptImage(image)
            .flatMap { extractedText -> AnyPublisher<StatementData, Error> in
                print("🟢 OCR Completed, extracting statement data")
                let statementData = self.extractStatementData(from: extractedText)
                return Just(statementData)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // Extract structured data from OCR text
    private func extractStatementData(from text: String) -> StatementData {
        print("🟢 Extracting data from statement text")
        
        // Initialize with empty values
        var data = StatementData()
        
        // Extract card number (last 4 digits)
        if let cardMatch = text.range(of: "(?:Card Number|Card No|Card)[^0-9]*(?:[*xX]\\s*){4,}([0-9]{4})", options: .regularExpression) {
            let cardText = String(text[cardMatch])
            if let numberMatch = cardText.range(of: "[0-9]{4}", options: .regularExpression) {
                data.cardNumber = String(cardText[numberMatch])
                print("🟢 Found card number: \(data.cardNumber ?? "")")
            }
        }
        
        // Extract statement period - fixed the range issue
        let periodPattern = "(?:Statement Period|Billing Period|Statement Date)[^0-9]*(\\d{1,2}[\\-/]\\d{1,2}[\\-/]\\d{2,4})\\s*(?:to|-)\\s*(\\d{1,2}[\\-/]\\d{1,2}[\\-/]\\d{2,4})"
        if let periodMatch = text.range(of: periodPattern, options: .regularExpression) {
            let periodText = String(text[periodMatch])
            
            // Find dates in the text more safely
            let dateRegex = try? NSRegularExpression(pattern: "\\d{1,2}[\\-/]\\d{1,2}[\\-/]\\d{2,4}")
            if let dateRegex = dateRegex {
                let nsString = periodText as NSString
                let matches = dateRegex.matches(in: periodText, range: NSRange(location: 0, length: nsString.length))
                
                if matches.count >= 2 {
                    // Get start and end dates
                    let startDateText = nsString.substring(with: matches[0].range)
                    let endDateText = nsString.substring(with: matches[1].range)
                    
                    // Parse dates
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd/MM/yyyy"
                    
                    // Try different formats if the first one fails
                    let dateFormats = ["dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy", "MM-dd-yyyy"]
                    
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if data.periodStart == nil, let date = dateFormatter.date(from: startDateText) {
                            data.periodStart = date
                        }
                        
                        if data.periodEnd == nil, let date = dateFormatter.date(from: endDateText) {
                            data.periodEnd = date
                        }
                        
                        if data.periodStart != nil && data.periodEnd != nil {
                            break
                        }
                    }
                    
                    print("🟢 Found statement period: \(data.periodStart?.description ?? "nil") to \(data.periodEnd?.description ?? "nil")")
                }
            }
        }
        
        // Modified - Extract multiple cashback entries
        var cashbackEntries: [Decimal] = []
        
        // Define patterns to find cashback entries
        let cashbackPatterns = [
            "(?:Cashback|Cash ?back|Reward|Rewards)[^0-9]*(?:Rs\\.?|₹)?\\s*([0-9,.]+)",
            "(?:Cashback earned|Cash ?back earned|Reward earned|Rewards earned)[^0-9]*(?:Rs\\.?|₹)?\\s*([0-9,.]+)",
            "(?:cashback credited|cash ?back credited|reward credited|rewards credited)[^0-9]*(?:Rs\\.?|₹)?\\s*([0-9,.]+)"
        ]
        
        for pattern in cashbackPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            if let regex = regex {
                let nsString = text as NSString
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
                
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let amountRange = match.range(at: 1)
                        let amountString = nsString.substring(with: amountRange).replacingOccurrences(of: ",", with: "")
                        if let amount = Decimal(string: amountString) {
                            cashbackEntries.append(amount)
                            print("🟢 Found cashback entry: \(amount)")
                        }
                    }
                }
            }
        }
        
        // If we found any cashback entries, sum them up
        if !cashbackEntries.isEmpty {
            let totalCashback = cashbackEntries.reduce(0, +)
            data.cashbackAmount = totalCashback
            data.cashbackEntries = cashbackEntries
            print("🟢 Total cashback amount: \(totalCashback) from \(cashbackEntries.count) entries")
        }
        
        // Extract bank name
        let bankNames = ["HDFC", "ICICI", "SBI", "Axis", "Kotak", "HSBC", "Citi", "Standard Chartered"]
        for bank in bankNames {
            if text.contains(bank) {
                data.bankName = bank
                print("🟢 Found bank name: \(bank)")
                break
            }
        }
        
        return data
    }
    
    // Statement data structure
    struct StatementData {
        var cardNumber: String?
        var periodStart: Date?
        var periodEnd: Date?
        var cashbackAmount: Decimal?
        var cashbackEntries: [Decimal]? // New field for individual entries
        var bankName: String?
        
        // Initialize with empty values
        init() {
            cardNumber = nil
            periodStart = nil
            periodEnd = nil
            cashbackAmount = nil
            cashbackEntries = nil
            bankName = nil
        }
    }
}
