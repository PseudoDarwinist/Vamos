import Foundation
import Combine
import SwiftUI
import CoreData

// Add extension for Notification.Name
extension Notification.Name {
    static let didExtractRawText = Notification.Name("didExtractRawText")
}

/// ViewModel for handling credit card statement processing
class StatementProcessorViewModel: ObservableObject {
    // Services
    private let pdfProcessor: PDFProcessor
    private let ocrService: OCRService
    private let textProcessor: TextProcessor
    private let geminiService: GeminiService
    private let postProcessor: StatementPostProcessor
    private let repository: CreditCardStatementRepository
    
    // Published properties
    @Published var statement: CreditCardStatement?
    @Published var isProcessing = false
    @Published var error: Error?
    @Published var savedStatements: [CreditCardStatement] = []
    @Published var rawOCRText: String = ""
    @Published var rawExtractedTransactions: [String] = []
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Progress tracking
    typealias ProgressCallback = (ProcessingResult) -> Void
    
    enum ProcessingResult {
        case progress(Double)
        case success
        case failure(Error)
    }
    
    enum ProcessingError: Error, LocalizedError {
        case pdfProcessingFailed
        case ocrFailed
        case aiProcessingFailed
        case savingFailed
        case invalidPDF
        
        var errorDescription: String? {
            switch self {
            case .pdfProcessingFailed:
                return "Failed to process PDF file"
            case .ocrFailed:
                return "Failed to extract text from the PDF"
            case .aiProcessingFailed:
                return "Failed to analyze the statement with AI"
            case .savingFailed:
                return "Failed to save the statement data"
            case .invalidPDF:
                return "The PDF file is invalid or corrupt"
            }
        }
    }
    
    /// Initialize with default services
    init(context: NSManagedObjectContext) {
        self.pdfProcessor = PDFProcessor()
        self.ocrService = OCRService()
        self.textProcessor = TextProcessor()
        self.geminiService = GeminiService()
        self.postProcessor = StatementPostProcessor()
        self.repository = CreditCardStatementRepository(context: context)
        
        // Load saved statements
        loadSavedStatements()
        
        // Set up notification observer for raw text extraction
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDirectTextExtraction(_:)),
            name: .didExtractRawText,
            object: nil
        )
    }
    
    /// Handle notification when text is extracted directly from PDF
    @objc private func handleDirectTextExtraction(_ notification: Notification) {
        if let extractedText = notification.object as? String {
            DispatchQueue.main.async {
                self.rawOCRText = extractedText
                
                // Extract potential transaction lines
                self.rawExtractedTransactions = self.extractTransactionLines(from: extractedText)
                print("📄 Found \(self.rawExtractedTransactions.count) potential transaction lines from direct text extraction")
            }
        }
    }
    
    /// Process the statement from a PDF file
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - progressCallback: Progress callback
    func processStatement(url: URL, progressCallback: @escaping ProgressCallback) {
        isProcessing = true
        error = nil
        
        Task {
            do {
                // Update initial progress
                await MainActor.run { progressCallback(.progress(0.05)) }
                
                // Render PDF to images - now includes hybrid approach
                // First tries direct text extraction, falls back to OCR if needed
                let renderedImages = try await pdfProcessor.renderPagesToImages(url: url) { progress in
                    // Scale progress to 0.05-0.50 range
                    let scaledProgress = 0.05 + (progress * 0.45)
                    Task { @MainActor in
                    progressCallback(.progress(scaledProgress))
                }
                }
                
                // Update progress after PDF rendering
                await MainActor.run { progressCallback(.progress(0.50)) }
                
                // Process the text - either from direct extraction or OCR
                var textToProcess = self.rawOCRText
                
                // If we don't have direct text, perform OCR
                if textToProcess.isEmpty {
                    // Extract text using OCR
                    let extractedTexts = try await ocrService.performOCR(on: renderedImages) { progress in
                        // Scale progress to 0.50-0.70 range
                        let scaledProgress = 0.50 + (progress * 0.20)
                        Task { @MainActor in
                    progressCallback(.progress(scaledProgress))
                }
                    }
                
                    // Update progress after OCR
                    await MainActor.run { progressCallback(.progress(0.70)) }
                
                    // Clean and format OCR text
                    textToProcess = textProcessor.cleanAndFormatText(pageTexts: extractedTexts)
                
                    // Store the OCR text for verification purposes
                    await MainActor.run {
                        self.rawOCRText = textToProcess
                        self.rawExtractedTransactions = self.extractTransactionLines(from: textToProcess)
                    }
                } else {
                    // We already have text from direct extraction, just update progress
                    await MainActor.run { progressCallback(.progress(0.70)) }
                }
                
                // Process with AI
                print("🧠 StatementProcessorViewModel: Processing text with AI")
                let statementData = try await geminiService.processStatement(text: textToProcess) { progress in
                    // Scale progress to 0.70-0.95 range
                    let scaledProgress = 0.70 + (progress * 0.25)
                    Task { @MainActor in
                        progressCallback(.progress(scaledProgress))
                    }
                }
                
                // Post-process the data (apply rules, clean up)
                let processedStatement = postProcessor.process(statementData)
                
                // Save the statement
                try await repository.save(processedStatement)
                
                // Reload saved statements
                loadSavedStatements()
                
                // Update UI
                await MainActor.run {
                    self.statement = processedStatement
                    self.isProcessing = false
                    progressCallback(.success)
                }
                
            } catch {
                print("🔴 StatementProcessorViewModel: Error processing statement - \(error)")
                await MainActor.run {
                    self.error = error
                    self.isProcessing = false
                    progressCallback(.failure(error))
                }
            }
        }
    }
    
    /// Extract potential transaction lines from raw text
    /// - Parameter text: Raw text from PDF
    /// - Returns: Array of potential transaction lines
    private func extractTransactionLines(from text: String) -> [String] {
        // Split text into lines
        let lines = text.components(separatedBy: .newlines)
        
        // Patterns to match transaction lines
        let patterns = [
            // Date pattern (e.g., "10 Apr 25", "10 APR 2025", "10/04/25")
            #"^\s*\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+\d{2,4}"#,
            
            // Date with UPI or other transaction identifiers
            #"UPI-[A-Z]+"#,
            
            // Transaction lines with amounts and transaction type (C/D)
            #".*\d+\.\d+\s+[CD]$"#,
            
            // Lines with currency symbols followed by amounts
            #".*₹\s*\d+[\.,]\d+"#,
            
            // SBI card style (date at beginning, amount at end)
            #"^\s*\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+\d{2,4}.*\d+\.\d+"#
        ]
        
        // Filter lines that match any of the patterns
        var transactionLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty {
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                       regex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) != nil {
                        transactionLines.append(trimmedLine)
                        break
            }
                }
            }
        }
        
        return transactionLines
    }
    
    /// Load saved statements from the repository
    private func loadSavedStatements() {
        do {
            let statements = try repository.getAllStatements()
            DispatchQueue.main.async {
                self.savedStatements = statements
            }
        } catch {
            print("🔴 StatementProcessorViewModel: Error loading saved statements - \(error)")
        }
    }
    
    /// Delete a statement
    /// - Parameter statement: Statement to delete
    func deleteStatement(_ statement: CreditCardStatement) {
        do {
            let success = try repository.delete(statement)
            if success {
                loadSavedStatements()
            }
        } catch {
            print("🔴 StatementProcessorViewModel: Error deleting statement - \(error)")
        }
    }
    
    /// Delete all statements
    func deleteAllStatements() {
        do {
            try repository.deleteAllStatements()
            loadSavedStatements()
        } catch {
            print("🔴 StatementProcessorViewModel: Error deleting all statements - \(error)")
        }
    }
    
    /// Public method to reload all statements
    func loadAllStatements() {
        loadSavedStatements()
    }
} 