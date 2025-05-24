import PDFKit
import UIKit
import Vision

enum PDFProcessingError: Error {
    case invalidPDF
    case contextCreationFailed
    case pageRenderingFailed
    case fileAccessError
}

class PDFProcessor {
    // Add OCRService dependency
    private let ocrService = OCRService()
    
    /// Renders each page of a PDF to a high-quality image (300 DPI)
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Array of CGImage objects, one per page
    func renderPagesToImages(url: URL, progressCallback: ((Double) -> Void)? = nil) async throws -> [CGImage] {
        print("📄 PDFProcessor: Starting to process PDF from URL: \(url.lastPathComponent)")
        
        // Try using the hybrid approach first
        print("📄 PDFProcessor: Trying hybrid text extraction approach")
        let (extractedText, textPages) = try await extractTextDirectlyFromPDF(url: url, progressCallback: { progress in
            // Scale progress to 0-30% of the total for direct text extraction
            progressCallback?(progress * 0.3)
        })
        
        if !extractedText.isEmpty {
            print("📄 PDFProcessor: Successfully extracted text directly from PDF")
            
            // Store the extracted text for later use
            Task { @MainActor in
                NotificationCenter.default.post(name: .didExtractRawText, object: extractedText)
            }
            
            // If we have text-based pages, we may not need to OCR everything
            // Just return placeholder images for the extracted pages
            if !textPages.isEmpty {
                print("📄 PDFProcessor: Using text-based pages, no need for OCR")
                
                // Create dummy images for the text pages (we won't actually use these for OCR)
                var dummyImages = [CGImage]()
                
                // Get PDF document
                guard let document = CGPDFDocument(url as CFURL) else {
                    throw PDFProcessingError.invalidPDF
                }
                
                // Create minimal images for each text page just to maintain the page structure
                for pageNum in textPages {
                    if let page = document.page(at: pageNum), let image = renderPageLowRes(page) {
                        dummyImages.append(image)
                    }
                }
                
                // Report 100% progress
                progressCallback?(1.0)
                
                return dummyImages
            }
        }
        
        // If direct text extraction failed or returned no text pages, fall back to the original approach
        print("📄 PDFProcessor: Falling back to OCR-based approach")
        
        // First pass: Identify transaction pages using low-resolution scanning
        print("📄 PDFProcessor: First pass - identifying transaction pages")
        let transactionPages = try await identifyTransactionPages(url: url, progressCallback: { progress in
            // Scale progress to 30-60% of the total for first pass
            progressCallback?(0.3 + progress * 0.3)
        })
        
        print("📄 PDFProcessor: Found \(transactionPages.count) transaction pages out of \(try await getPDFPageCount(url: url))")
        
        if transactionPages.isEmpty {
            print("⚠️ PDFProcessor: No transaction pages found, will process all pages")
            // Fall back to processing all pages if no transaction pages were identified
            return try await processPagesInBatches(url: url, progressCallback: { progress in
                // Scale progress to 60-100% for second pass
                progressCallback?(0.6 + progress * 0.4)
            })
        }
        
        // Second pass: Process only transaction pages at high resolution
        print("📄 PDFProcessor: Second pass - processing only transaction pages at high resolution")
        return try await processSpecificPages(url: url, pageNumbers: transactionPages, progressCallback: { progress in
            // Scale progress to 60-100% for second pass
            progressCallback?(0.6 + progress * 0.4)
        })
    }
    
    /// Extract text directly from PDF without OCR
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Tuple of (extracted text, array of page numbers with text)
    private func extractTextDirectlyFromPDF(url: URL, progressCallback: ((Double) -> Void)? = nil) async throws -> (String, [Int]) {
        print("📄 PDFProcessor: Attempting to extract text directly from PDF")
        
        // Create PDF document
        guard let pdfDoc = PDFDocument(url: url) else {
            throw PDFProcessingError.invalidPDF
        }
        
        var fullTextBlocks: [String] = []
        var textBasedPages: [Int] = []
        
        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            
            // Check if the page has text
            if isTextBasedPage(page) {
                print("📄 PDFProcessor: Page \(pageIndex + 1) has native text layer")
                
                // Extract text directly
                if let text = page.string, !text.isEmpty {
                    let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedText.count > 20 { // Only consider substantial text
                        fullTextBlocks.append("===PAGE \(pageIndex + 1)===\n\(cleanedText)")
                        textBasedPages.append(pageIndex + 1) // 1-based page numbering
                    }
                }
            } else {
                print("📄 PDFProcessor: Page \(pageIndex + 1) has no text layer, would need OCR")
            }
            
            // Report progress
            let progress = Double(pageIndex + 1) / Double(pdfDoc.pageCount)
            await MainActor.run {
                progressCallback?(progress)
            }
        }
        
        // Normalize numbers that Vision sometimes splits
        let cleanedText = fullTextBlocks.joined(separator: "\n")
            .replacingOccurrences(of: #"(\d)\s+(\d)"#, with: "$1$2", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\d),(?=\d{2}\b)"#, with: "", options: .regularExpression)
        
        return (cleanedText, textBasedPages)
    }
    
    /// Check if a PDF page has a text layer
    /// - Parameter page: The PDF page to check
    /// - Returns: Boolean indicating if the page has text
    private func isTextBasedPage(_ page: PDFPage) -> Bool {
        // Get the text from the page
        guard let text = page.string else { return false }
        
        // Check if there's meaningful text (more than just a few characters)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.count > 20
    }
    
    /// Identify pages that contain transaction tables using low-resolution scanning
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Array of page numbers (1-based) that likely contain transaction data
    private func identifyTransactionPages(url: URL, progressCallback: ((Double) -> Void)? = nil) async throws -> [Int] {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw PDFProcessingError.invalidPDF
        }
        
        let pageCount = document.numberOfPages
        print("📄 PDFProcessor: Scanning \(pageCount) pages for transaction tables")
        
        var transactionPages = [Int]()
        
        for pageNumber in 1...pageCount {
            // Check for cancellation
            try Task.checkCancellation()
            
            guard let page = document.page(at: pageNumber) else {
                continue
            }
            
            // Render page at low resolution (72 DPI) for quick scanning
            if let lowResImage = renderPageLowRes(page) {
                if await isTransactionPage(lowResImage) {
                    print("✅ PDFProcessor: Page \(pageNumber) contains transaction data")
                    transactionPages.append(pageNumber)
                } else {
                    print("📄 PDFProcessor: Page \(pageNumber) does not contain transaction data")
                }
            }
            
            // Report progress
            let progress = Double(pageNumber) / Double(pageCount)
            await MainActor.run {
                progressCallback?(progress)
            }
        }
        
        return transactionPages
    }
    
    /// Determine if a page contains transaction data using fast OCR
    /// - Parameter image: Low-resolution image of the page
    /// - Returns: Boolean indicating if the page likely contains transaction data
    private func isTransactionPage(_ image: CGImage) async -> Bool {
        do {
            // Use OCRService's quickOCR instead of implementing OCR directly
            let extractedText = try await ocrService.quickOCR(image)
            
            // Log the raw extracted text to help with debugging
            print("📄 Raw OCR Text Sample: \(extractedText.prefix(200))...")
            
            // Case-insensitive matching
            let text = extractedText.lowercased()
            
            // Check for common transaction table headers with more patterns specific to SBI
            let containsDate = text.contains("date") || 
                               text.contains("dt") || 
                               text.contains("posting date") ||
                               text.contains("transaction date")
                              
            let containsAmount = text.contains("amount") || 
                                text.contains("amt") || 
                                text.contains("₹") || 
                                text.contains("rs") ||
                                text.contains("inr")
            
            let containsTransaction = text.contains("transaction") || 
                                     text.contains("particulars") || 
                                     text.contains("description") || 
                                     text.contains("narration") ||
                                     text.contains("details") ||
                                     text.contains("reference") ||
                                     text.contains("trans")
                                    
            // Add detection of column-like patterns (common in SBI statements)
            let containsTabularData = text.contains("|") || 
                                     text.contains("----") ||
                                     text.contains("____") ||
                                     text.contains("₹") ||
                                     (text.contains("d") && text.contains("c")) // Debit/Credit markers
            
            // Additional patterns for SBI Card statements
            let containsSBIPatterns = text.contains("upi") || 
                                     text.contains("debit") || 
                                     text.contains("credit") ||
                                     text.contains("apr") ||
                                     text.contains("domestic") ||
                                     text.contains("petroleum") ||
                                     (text.contains("₹") && text.contains("d"))
            
            // Detect regular sequences of dates which often indicate transaction tables
            let containsDatePattern = privateMatches(pattern: "\\d{1,2}\\s+(apr|jan|feb|mar|may|jun|jul|aug|sep|oct|nov|dec)\\s+\\d{2}", in: text)
            
            // Implement a weighted scoring system for better detection
            var score = 0
            if containsDate { score += 1 }
            if containsAmount { score += 1 }
            if containsTransaction { score += 1 }
            if containsTabularData { score += 2 }  // Higher weight for table structures
            if containsSBIPatterns { score += 2 }  // Higher weight for specific SBI patterns
            if containsDatePattern { score += 3 }  // Highest weight for date patterns typical in transaction tables
            
            print("📄 Page transaction detection score: \(score)")
            
            // A page with a score of 3 or higher either has traditional table headers
            // or with a transaction info and statement period will be considered
            let isTransactionPage = score >= 3
            
            return isTransactionPage
        } catch {
            print("🔴 Error performing quick OCR for page filtering: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Render a single PDF page to a low-resolution image (72 DPI)
    /// - Parameter page: PDF page to render
    /// - Returns: Optional CGImage
    private func renderPageLowRes(_ page: CGPDFPage) -> CGImage? {
        let pageRect = page.getBoxRect(.mediaBox)
        // Use native resolution (72 DPI) for quick scanning
        let scale: CGFloat = 1.0
        
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Use autoreleasepool to help manage memory
        return autoreleasepool {
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                print("🔴 PDFProcessor: Failed to create graphics context")
                return nil
            }
            
            context.setAllowsAntialiasing(true)
            context.interpolationQuality = .low // Lower quality for speed
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(page)
            
            return context.makeImage()
        }
    }
    
    /// Process specific pages of a PDF at high resolution
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - pageNumbers: Array of page numbers to process
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Array of CGImage objects for the specified pages
    private func processSpecificPages(url: URL, pageNumbers: [Int], progressCallback: ((Double) -> Void)? = nil) async throws -> [CGImage] {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw PDFProcessingError.invalidPDF
        }
        
        var images = [CGImage]()
        
        for (index, pageNumber) in pageNumbers.enumerated() {
            // Check for cancellation
            try Task.checkCancellation()
            
            guard let page = document.page(at: pageNumber) else {
                continue
            }
            
            // Render page at high resolution
            if let image = renderPage(page) {
                images.append(image)
                print("✅ PDFProcessor: Successfully rendered transaction page \(pageNumber) at high resolution")
            }
            
            // Report progress
            let progress = Double(index + 1) / Double(pageNumbers.count)
            await MainActor.run {
                progressCallback?(progress)
            }
        }
        
        return images
    }
    
    /// Get the total number of pages in a PDF document
    /// - Parameter url: URL of the PDF file
    /// - Returns: Number of pages
    private func getPDFPageCount(url: URL) async throws -> Int {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw PDFProcessingError.invalidPDF
        }
        
        return document.numberOfPages
    }
    
    // MARK: - Legacy methods for backward compatibility
    
    /// Process PDF pages in batches to manage memory more efficiently
    /// - Parameters:
    ///   - url: URL of the PDF file
    ///   - batchSize: Number of pages to process in each batch
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: Array of CGImage objects, one per page
    func processPagesInBatches(url: URL, batchSize: Int = 5, progressCallback: ((Double) -> Void)? = nil) async throws -> [CGImage] {
        print("📄 PDFProcessor: Starting to process PDF in batches from URL: \(url.lastPathComponent)")
        
        // Verify the file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("🔴 PDFProcessor: File does not exist at path: \(url.path)")
            throw PDFProcessingError.fileAccessError
        }
        
        guard let document = CGPDFDocument(url as CFURL) else {
            print("🔴 PDFProcessor: Unable to create CGPDFDocument from URL")
            throw PDFProcessingError.invalidPDF
        }
        
        let pageCount = document.numberOfPages
        var allImages = [CGImage]()
        
        print("📄 PDFProcessor: Processing PDF with \(pageCount) pages in batches of \(batchSize)")
        
        // Process pages in batches
        for startPage in stride(from: 1, to: pageCount + 1, by: batchSize) {
            try Task.checkCancellation() // Check for cancellation at start of each batch
            
            let endPage = min(startPage + batchSize - 1, pageCount)
            print("📄 PDFProcessor: Processing batch from page \(startPage) to \(endPage)")
            
            var batchImages = [CGImage]()
            
            // Process current batch
            for pageNumber in startPage...endPage {
                guard let page = document.page(at: pageNumber) else {
                    print("⚠️ PDFProcessor: Could not get page \(pageNumber)")
                    continue
                }
                
                if let renderedImage = renderPage(page) {
                    batchImages.append(renderedImage)
                } else {
                    print("🔴 PDFProcessor: Failed to render page \(pageNumber)")
                }
            }
            
            // Append current batch to all images
            allImages.append(contentsOf: batchImages)
            
            // Report progress
            let progress = Double(endPage) / Double(pageCount)
            await MainActor.run {
                progressCallback?(progress)
            }
        }
        
        print("✅ PDFProcessor: Successfully processed \(allImages.count) pages")
        return allImages
    }
    
    /// Renders a single PDF page to a high-quality image
    /// - Parameter page: PDF page to render
    /// - Returns: Optional CGImage
    private func renderPage(_ page: CGPDFPage) -> CGImage? {
        let pageRect = page.getBoxRect(.mediaBox)
        let scale: CGFloat = 300.0 / 72.0
        
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Use autoreleasepool to help manage memory
        return autoreleasepool {
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                print("🔴 PDFProcessor: Failed to create graphics context")
                return nil
            }
            
            context.setAllowsAntialiasing(true)
            context.interpolationQuality = .high
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(page)
            
            return context.makeImage()
        }
    }
    
    /// Private method to check if a string matches a regex pattern
    /// - Parameters:
    ///   - pattern: Regex pattern to match
    ///   - string: String to check
    /// - Returns: True if string matches pattern
    private func privateMatches(pattern: String, in string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
} 