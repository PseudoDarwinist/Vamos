import Foundation
import Combine
import PDFKit

class LandingAIService {
    // Your API key - in a real app, this should be securely stored
    private let apiKey = "OTRqOWxwdHJmNmY4dXN5cW02bnhoOkRpZGVNc2MzaVlMWWRnUldHMkVMbWNCT1F6TWtOTWo3" // ⚠️ Replace with your actual API key
    private let baseURL = "https://api.va.landing.ai/v1/tools/agentic-document-analysis"
    
    // Debug flag - set to true for additional logging
    private let debugMode = true
    
    // Create a minimal PDF for testing
    private func createMinimalTestPDF() -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            "TEST".draw(at: CGPoint(x: 10, y: 10), withAttributes: nil)
        }
    }
    
    // Test with a minimal PDF sample
    func testAPIConnection() -> AnyPublisher<Bool, Error> {
        print("🟢 LandingAIService: Testing API connection")
        
        // Create a very small sample PDF to test with
        let testPdfData = createMinimalTestPDF()
        
        return processDocumentWithRawData(pdfData: testPdfData)
            .map { _ -> Bool in
                print("✅ LandingAIService: API connection test succeeded")
                return true
            }
            .catch { error -> AnyPublisher<Bool, Error> in
                print("❌ LandingAIService: API connection test failed: \(error.localizedDescription)")
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // Extract information from PDF document
    func extractPDFInfo(pdfDocument: PDFDocument) -> AnyPublisher<[String: Any], Error> {
        print("🟢 LandingAIService: Starting PDF extraction")
        
        if debugMode {
            print("🔬 LandingAIService: PDF document page count: \(pdfDocument.pageCount)")
        }
        
        guard let pdfData = pdfDocument.dataRepresentation() else {
            print("🔴 LandingAIService: Failed to get PDF data representation")
            return Fail(error: NSError(domain: "LandingAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get PDF data"]))
                .eraseToAnyPublisher()
        }
        
        // Log PDF data size
        let pdfSizeKB = Double(pdfData.count) / 1024.0
        print("🟢 LandingAIService: PDF data size: \(pdfSizeKB) KB")
        
        // Send the raw PDF data
        return processDocumentWithRawData(pdfData: pdfData)
    }
    
    // Helper method to compress PDF if needed
    private func compressPDF(data: Data) -> Data {
        // Try to create a new PDF with the same content
        if let pdfDocument = PDFDocument(data: data),
           let compressedData = pdfDocument.dataRepresentation() {
            // If new representation is smaller, use it
            if compressedData.count < data.count {
                return compressedData
            }
        }
        
        // Return original if compression fails or doesn't save space
        return data
    }
    
    // Process document using LandingAI API with raw PDF data
    private func processDocumentWithRawData(pdfData: Data) -> AnyPublisher<[String: Any], Error> {
        print("🟢 LandingAIService: Preparing API request with raw PDF data")
        
        // Try to compress the PDF for faster processing
        let compressedData = compressPDF(data: pdfData)
        let compressionRatio = Float(compressedData.count) / Float(pdfData.count) * 100.0
        print("🟢 LandingAIService: Compressed PDF from \(pdfData.count / 1024) KB to \(compressedData.count / 1024) KB (\(compressionRatio.rounded())%)")
        
        // Use the compressed data if it's significantly smaller
        let dataToSend = compressionRatio < 95 ? compressedData : pdfData
        
        do {
            guard let url = URL(string: baseURL) else {
                print("🔴 LandingAIService: Invalid URL")
                return Fail(error: NSError(domain: "LandingAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                    .eraseToAnyPublisher()
            }
            
            // Create multipart form data
            let boundary = "Boundary-\(UUID().uuidString)"
            let contentType = "multipart/form-data; boundary=\(boundary)"
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
            request.addValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 120 // 60 seconds should be plenty for small PDFs
            
            // Create multipart form data body with PDF
            var body = Data()
            
            // Add PDF data part
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"pdf\"; filename=\"document.pdf\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
            body.append(dataToSend)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add final boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            // Log request size for debugging
            if debugMode {
                let requestSizeKB = Double(body.count) / 1024.0
                print("🔬 LandingAIService: Request payload size: \(requestSizeKB) KB")
                print("🔬 LandingAIService: Request Headers: \(request.allHTTPHeaderFields?.filter { $0.key.lowercased() != "authorization" } ?? [:])")
            }
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { data, response -> Data in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("🔴 LandingAIService: Invalid response type")
                        throw NSError(domain: "LandingAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    }
                    
                    print("🟢 LandingAIService: Received response with status code: \(httpResponse.statusCode)")
                    
                    // Print raw response data for debugging if enabled
                    if self.debugMode {
                        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                        print("🔬 LandingAIService: Raw API response: \(responseString)")
                    }
                    
                    guard 200..<300 ~= httpResponse.statusCode else {
                        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                        print("🔴 LandingAIService: API error with status code \(httpResponse.statusCode)")
                        print("🔴 LandingAIService: Response body: \(responseString)")
                        
                        throw NSError(domain: "LandingAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error with status code \(httpResponse.statusCode)"])
                    }
                    
                    print("🟢 LandingAIService: Successful response received")
                    return data
                }
                .flatMap { data -> AnyPublisher<[String: Any], Error> in
                    do {
                        // Log parsed JSON response if debug mode is enabled
                        if self.debugMode, let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []),
                           let jsonData = try? JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted),
                           let jsonStr = String(data: jsonData, encoding: .utf8) {
                            print("🔬 LandingAIService: Parsed JSON response:\n\(jsonStr)")
                        }
                        
                        // Parse the JSON response
                        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                            print("🔴 LandingAIService: Could not parse response as JSON dictionary")
                            throw NSError(domain: "LandingAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format"])
                        }
                        
                        print("🟢 LandingAIService: Successfully parsed JSON response")
                        
                        // Extract data node from response
                        guard let responseData = json["data"] as? [String: Any] else {
                            print("🔴 LandingAIService: No data field in response")
                            return Just([:]).setFailureType(to: Error.self).eraseToAnyPublisher()
                        }
                        
                        print("🟢 LandingAIService: Found data in the response")
                        
                        // Process LandingAI's structured response
                        var result: [String: Any] = [:]
                        
                        // Get chunks which contain structured data
                        let chunks = responseData["chunks"] as? [[String: Any]] ?? []
                        let markdown = responseData["markdown"] as? String ?? ""
                        
                        // Extract merchant name - First check for branded content
                        var merchantName = "Unknown Merchant"
                        // Look for logo description or company name in markdown
                        if markdown.contains("Country Delight") {
                            merchantName = "Country Delight"
                        } else if markdown.contains("Dairy Products") || markdown.contains("Beejapuri Dairy") {
                            merchantName = "Beejapuri Dairy"
                        }
                        
                        // Extract merchant name from chunks
                        for chunk in chunks {
                            if let text = chunk["text"] as? String {
                                // Check if it's a business name
                                if text.contains("Pvt. Ltd.") || text.contains("Private Limited") {
                                    // Extract company name
                                    if let range = text.range(of: "Billed by ") {
                                        let startIndex = range.upperBound
                                        if let endRange = text.range(of: " Pvt. Ltd.", range: startIndex..<text.endIndex) {
                                            merchantName = String(text[startIndex..<endRange.lowerBound])
                                        }
                                    }
                                }
                                
                                // Look for "Invoice" heading with company name
                                if text.contains("Invoice") && text.contains("Country Delight") {
                                    merchantName = "Country Delight"
                                }
                            }
                        }
                        result["merchant_name"] = merchantName
                        
                        // Extract date
                        var dateString = ""
                        // Look for date in markdown
                        if let dateRange = markdown.range(of: "Delivery Date\\**: \\s*([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})", options: .regularExpression) {
                            let dateSubstring = markdown[dateRange]
                            if let dateMatch = dateSubstring.range(of: "[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}", options: .regularExpression) {
                                dateString = String(dateSubstring[dateMatch])
                            }
                        }
                        
                        // If no date found, look in chunks
                        if dateString.isEmpty {
                            for chunk in chunks {
                                if let text = chunk["text"] as? String, 
                                   let chunkType = chunk["chunk_type"] as? String, 
                                   chunkType == "key_value" && text.contains("Date") {
                                    if let dateMatch = text.range(of: "[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}", options: .regularExpression) {
                                        dateString = String(text[dateMatch])
                                    }
                                }
                            }
                        }
                        
                        // Convert DD/MM/YYYY to YYYY-MM-DD
                        if !dateString.isEmpty {
                            let components = dateString.split(separator: "/")
                            if components.count == 3 {
                                if components[0].count <= 2 && components[1].count <= 2 && components[2].count == 4 {
                                    // Format is DD/MM/YYYY
                                    dateString = "\(components[2])-\(components[1])-\(components[0])"
                                }
                            }
                        }
                        result["date"] = dateString
                        
                        // Extract total amount
                        var totalAmount = ""
                        // Look for total amount in tables
                        if let tableRange = markdown.range(of: "<td[^>]*><strong>.*?Rs\\.\\s*([0-9.]+).*?<\\/strong><\\/td>", options: .regularExpression) {
                            let tableText = markdown[tableRange]
                            if let amountMatch = tableText.range(of: "Rs\\.\\s*([0-9.]+)", options: .regularExpression) {
                                let amountText = tableText[amountMatch]
                                if let numberMatch = amountText.range(of: "[0-9.]+", options: .regularExpression) {
                                    totalAmount = String(amountText[numberMatch])
                                }
                            }
                        }
                        
                        // Also check for amount in summary section
                        if totalAmount.isEmpty {
                            if let summaryRange = markdown.range(of: "\\*\\*Items Total\\*\\*: Rs\\.\\s*(?:<s>.*?<\\/s>\\s*)?([0-9.]+)", options: .regularExpression) {
                                let summaryText = markdown[summaryRange]
                                if let amountMatch = summaryText.range(of: "[0-9.]+(?!<\\/s>)", options: .regularExpression) {
                                    totalAmount = String(summaryText[amountMatch])
                                }
                            }
                        }
                        
                        result["total_amount"] = totalAmount
                        
                        // Determine category
                        var category = "Miscellaneous"
                        if markdown.contains("Dairy Products") || 
                           markdown.contains("Milk") || 
                           markdown.contains("Buffalo Milk") || 
                           markdown.contains("Cow Milk") {
                            category = "Groceries"
                        }
                        result["category"] = category
                        
                        return Just(result)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    } catch {
                        print("🔴 LandingAIService: Error parsing response: \(error)")
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                }
                .eraseToAnyPublisher()
        } catch {
            print("🔴 LandingAIService: Error preparing request: \(error.localizedDescription)")
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}