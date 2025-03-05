import Foundation
import Combine

// Response models for Gemini API
struct GeminiResponse: Codable {
    let candidates: [Candidate]
    let promptFeedback: PromptFeedback?
}

struct Candidate: Codable {
    let content: Content
    let finishReason: String?
    let safetyRatings: [SafetyRating]?
    
    // Custom decoding to handle missing fields
    enum CodingKeys: String, CodingKey {
        case content, finishReason, safetyRatings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(Content.self, forKey: .content)
        finishReason = try container.decodeIfPresent(String.self, forKey: .finishReason)
        safetyRatings = try container.decodeIfPresent([SafetyRating].self, forKey: .safetyRatings)
    }
}

struct Content: Codable {
    let parts: [Part]
    let role: String
}

struct Part: Codable {
    let text: String?
}

struct SafetyRating: Codable {
    let category: String
    let probability: String
}

struct PromptFeedback: Codable {
    let safetyRatings: [SafetyRating]?
}

// Request models for Gemini API
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String = "user"
}

struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?
    
    init(text: String? = nil, inlineData: GeminiInlineData? = nil) {
        self.text = text
        self.inlineData = inlineData
    }
}

struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String // Base64 encoded data
}

// MARK: - Gemini Service
class GeminiService {
    // API key
    private let apiKey = "AIzaSyD_49Jhf8WZ4irHzaK8KqiEHOw-ILQ3Cow"
    private let baseURL = "https://generativelanguage.googleapis.com/v1"
    
    // Gemini model names
    private enum Model: String {
        case flash = "models/gemini-2.0-flash"
        case flashLite = "models/gemini-2.0-flash-lite"
    }
    
    // Current model with fallback capability
    private var currentModel: Model = .flash
    
    // MARK: - Receipt Processing (for expense tracking)
    
    /// Process receipt image and extract transaction details
    /// - Parameter imageData: JPEG data of the receipt image
    /// - Returns: A publisher that emits a dictionary with extracted receipt information
    func extractReceiptInfo(imageData: Data) -> AnyPublisher<[String: Any], Error> {
        print("🧾 RECEIPT PROCESSING: Starting receipt info extraction")
        
        // Validate image data
        guard validateImageData(imageData) else {
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]))
                .eraseToAnyPublisher()
        }
        
        // Convert image to base64
        let base64String = imageData.base64EncodedString()
        
        // Create image part for multimodal input
        let imagePart = GeminiPart(
            inlineData: GeminiInlineData(
                mimeType: "image/jpeg",
                data: base64String
            )
        )
        
        // Create optimized prompt for receipt information extraction
        let textPart = GeminiPart(
            text: """
            Extract the following information from this receipt or invoice:
            - date (in format YYYY-MM-DD)
            - merchant_name (the store or service provider)
            - platform_name (if any delivery platform is mentioned like Swiggy, Zomato)
            - total_amount (the total amount paid - ONLY numbers)
            - category (e.g., Food & Dining, Transportation, Shopping)
            
            IMPORTANT RULES:
            1. For total_amount, extract ONLY the numeric value (e.g., 1187, not "₹1187" or "Rs. 1187") 
            2. Look for "Total," "Grand Total," "Amount Paid," "Bill Amount" - this is the most important field
            3. If there's a delivery platform (Swiggy, Zomato), identify the actual merchant (restaurant name)
            4. Choose the best category from: Food & Dining, Groceries, Transportation, Shopping, Entertainment, Health
            
            Format the response as a JSON object with these exact keys.
            If you cannot find a specific piece of information, use null for that field.
            """
        )
        
        // Use Flash model for multimodal capabilities (image processing)
        let model = Model.flash
        
        // Create request with image and text prompt
        let content = GeminiContent(parts: [imagePart, textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: model, body: requestBody)
            .flatMap { response -> AnyPublisher<[String: Any], Error> in
                self.processGeminiResponse(response: response, context: "Receipt")
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Statement Processing (for cashback tracking)
    
    /// Process credit card statement image and extract cashback information
    /// - Parameter imageData: JPEG data of the statement image
    /// - Returns: A publisher that emits a dictionary with extracted statement information
    func extractStatementInfo(imageData: Data) -> AnyPublisher<[String: Any], Error> {
        print("💳 STATEMENT PROCESSING: Starting statement info extraction")
        
        // Validate image data
        guard validateImageData(imageData) else {
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]))
                .eraseToAnyPublisher()
        }
        
        // Convert image to base64
        let base64String = imageData.base64EncodedString()
        
        // Create image part for multimodal input
        let imagePart = GeminiPart(
            inlineData: GeminiInlineData(
                mimeType: "image/jpeg",
                data: base64String
            )
        )
        
        // Create optimized prompt for credit card statement information extraction
        let textPart = GeminiPart(
            text: """
            Extract the following information from this credit card statement:
            - date (in format YYYY-MM-DD)
            - merchant_name (the bank or credit card issuer)
            - platform_name (if any delivery platform is mentioned)
            - total_amount (total cashback amount, sum of all cashback entries)
            - cashback_entries (array of individual cashback amounts)
            - category (e.g., Banking, Credit Card)
            
            IMPORTANT: Look for multiple cashback entries or rewards throughout the entire statement.
            These might appear as separate line items with terms like:
            - "Cashback credited"
            - "Reward points"
            - "Cashback earned"
            - "Bonus cashback"
            - "Cashback"
            
            Format the response as a JSON object with these exact keys.
            For cashback_entries, provide an array of all individual cashback amounts found.
            If you cannot find a specific piece of information, use null for that field.
            """
        )
        
        // Use Flash model for more complex document analysis
        let model = Model.flash
        
        // Create request with image and text prompt
        let content = GeminiContent(parts: [imagePart, textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: model, body: requestBody)
            .flatMap { response -> AnyPublisher<[String: Any], Error> in
                self.processGeminiResponse(response: response, context: "Statement")
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - PDF Document Processing (for invoice PDFs)
    
    /// Process PDF document and extract transaction details
    /// - Parameter pdfData: PDF document data
    /// - Returns: A publisher that emits a Transaction object
    func processPDFDocument(pdfData: Data) -> AnyPublisher<Transaction, Error> {
        print("📄 PDF PROCESSING: Starting PDF document processing")
        
        return extractPDFInfo(pdfData: pdfData)
            .map { data -> Transaction in
                // Debug logging
                print("📊 PDF DATA EXTRACTED:")
                print("  - Raw data: \(data)")
                
                // Parse extracted data with robust error handling
                let amount: Decimal
                if let amountString = data["total_amount"] as? String {
                    // Remove currency symbols and whitespace
                    let cleanedString = amountString
                        .replacingOccurrences(of: "₹", with: "")
                        .replacingOccurrences(of: "Rs.", with: "")
                        .replacingOccurrences(of: "Rs", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    amount = Decimal(string: cleanedString) ?? 0.0
                } else if let amountNumber = data["total_amount"] as? NSNumber {
                    amount = Decimal(amountNumber.doubleValue)
                } else if let amountDouble = data["total_amount"] as? Double {
                    amount = Decimal(amountDouble)
                } else {
                    amount = 0.0
                }
                
                // Robust date parsing
                let date: Date
                if let dateString = data["date"] as? String {
                    date = self.parseDate(dateString) ?? Date()
                } else {
                    date = Date()
                }
                
                let merchant = data["merchant_name"] as? String ?? "Unknown Merchant"
                let categoryName = data["category"] as? String ?? "Miscellaneous"
                
                return Transaction(
                    amount: amount,
                    date: date,
                    merchant: merchant,
                    category: Category.sample(name: categoryName),
                    sourceType: .digital
                )
            }
            .eraseToAnyPublisher()
    }
    
    /// Extract information from PDF document data
    /// - Parameter pdfData: PDF document data
    /// - Returns: A publisher that emits a dictionary with extracted PDF information
    func extractPDFInfo(pdfData: Data) -> AnyPublisher<[String: Any], Error> {
        print("📄 PDF PROCESSING: Extracting PDF information")
        
        // Convert PDF data to base64
        let base64String = pdfData.base64EncodedString()
        
        // Create PDF part for multimodal input
        let pdfPart = GeminiPart(
            inlineData: GeminiInlineData(
                mimeType: "application/pdf",
                data: base64String
            )
        )
        
        // Create optimized prompt for PDF information extraction
        let textPart = GeminiPart(
            text: """
            Extract the following information from this invoice/receipt PDF:
            1. Date of purchase (format as YYYY-MM-DD)
            2. Merchant/vendor name
            3. Total amount paid (numeric value only)
            4. Category (e.g., Fuel, Food, Electronics)
            
            IMPORTANT:
            - For total_amount, extract ONLY the numeric value
            - Look for "Total," "Amount Due," "Amount Payable," "Grand Total"
            - Choose a specific category when possible
            
            Format the response as a JSON object with these exact keys:
            {
              "date": "YYYY-MM-DD",
              "merchant_name": "Store Name",
              "total_amount": "123.45",
              "category": "Category Name"
            }
            
            If information is not found, use null for that field.
            """
        )
        
        // Use Flash model for complex document analysis
        let model = Model.flash
        
        // Create request with PDF and text prompt
        let content = GeminiContent(parts: [pdfPart, textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: model, body: requestBody)
            .flatMap { response -> AnyPublisher<[String: Any], Error> in
                self.processGeminiResponse(response: response, context: "PDF")
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Narrative Generation (for spending insights)
    
    /// Generate a narrative summary of spending habits
    /// - Parameter transactions: Array of transactions to analyze
    /// - Returns: A publisher that emits a narrative string
    func generateNarrativeSummary(transactions: [Transaction]) -> AnyPublisher<String, Error> {
        print("🔍 NARRATIVE: Starting narrative generation")
        
        // For simple text generation, use the more efficient Flash-Lite model
        let model = Model.flashLite
        
        // Create transaction descriptions for the prompt
        var transactionDescriptions = ""
        for transaction in transactions {
            transactionDescriptions += "- \(transaction.merchant): ₹\(transaction.amount) on \(transaction.date.relativeDescription()) in category \(transaction.category.name)\n"
        }
        
        // Create optimized prompt for narrative generation
        let textPart = GeminiPart(
            text: """
            Based on the following transactions, generate a friendly, nature-themed summary of spending habits:
            
            \(transactionDescriptions)
            
            Rules:
            1. Keep the response conversational and engaging
            2. Use plant/growth metaphors (e.g., "your spending is blooming")
            3. Highlight the top spending category
            4. Compare to previous spending if possible
            5. Limit to 2-3 sentences
            """
        )
        
        // Create request with text prompt
        let content = GeminiContent(parts: [textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: model, body: requestBody)
            .map { response -> String in
                guard let text = response.candidates.first?.content.parts.first?.text else {
                    print("🔴 NARRATIVE: No text in narrative response")
                    return "Your spending patterns are growing steadily. Keep nurturing your financial garden!"
                }
                print("🟢 NARRATIVE: Successfully generated narrative")
                return text
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Query Answering (for user questions)
    
    /// Answer user queries about spending data
    /// - Parameters:
    ///   - query: User question
    ///   - transactions: Array of transactions to analyze
    /// - Returns: A publisher that emits an answer string
    func answerSpendingQuery(query: String, transactions: [Transaction]) -> AnyPublisher<String, Error> {
        print("❓ QUERY: Starting query answering")
        
        // Use Flash for more complex analysis and reasoning
        let model = Model.flash
        
        // Create transaction descriptions for the prompt
        var transactionDescriptions = ""
        for transaction in transactions {
            transactionDescriptions += "- \(transaction.merchant): ₹\(transaction.amount) on \(transaction.date.relativeDescription()) in category \(transaction.category.name)\n"
        }
        
        // Create optimized prompt for query answering
        let textPart = GeminiPart(
            text: """
            Here are my recent transactions:
            
            \(transactionDescriptions)
            
            Given the above data, answer this question in a friendly, nature-themed way: "\(query)"
            
            Rules:
            1. Keep the response conversational using plant/nature metaphors
            2. Provide specific data and insights from the transactions
            3. Limit to 3-4 sentences for clarity
            4. If there's not enough data to answer, be honest about it
            """
        )
        
        // Create request with text prompt
        let content = GeminiContent(parts: [textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: model, body: requestBody)
            .map { response -> String in
                guard let text = response.candidates.first?.content.parts.first?.text else {
                    print("🔴 QUERY: No text in query response")
                    return "I couldn't analyze your spending right now. Let's try again later when your financial garden is ready for review."
                }
                print("🟢 QUERY: Successfully answered query")
                return text
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Validate image data
    /// - Parameter imageData: Image data to validate
    /// - Returns: Boolean indicating if data is valid
    private func validateImageData(_ imageData: Data) -> Bool {
        if imageData.isEmpty {
            print("🔴 ERROR: Image data is empty")
            return false
        }
        
        // Log image data size
        let imageSizeKB = Double(imageData.count) / 1024.0
        print("🟢 Image data size: \(imageSizeKB) KB")
        
        // Check if image is too large for API
        if imageSizeKB > 10240 { // 10MB limit for most APIs
            print("🔴 ERROR: Image is too large for API (\(imageSizeKB) KB)")
            return false
        }
        
        return true
    }
    
    /// Process Gemini API response
    /// - Parameters:
    ///   - response: Gemini API response
    ///   - context: Context string for logging
    /// - Returns: A publisher that emits a dictionary with extracted information
    private func processGeminiResponse(response: GeminiResponse, context: String) -> AnyPublisher<[String: Any], Error> {
        guard let text = response.candidates.first?.content.parts.first?.text,
              let data = text.data(using: .utf8) else {
            print("🔴 \(context): No text in response or failed to convert to data")
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Gemini API"])).eraseToAnyPublisher()
        }
        
        print("🟢 \(context): Received text response")
        
        // Try to parse JSON response using multiple strategies
        do {
            // Strategy 1: Direct JSON parsing
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("🟢 \(context): Successfully parsed JSON response")
                return Just(json).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            
            // Strategy 2: Extract JSON from text if embedded
            if let extractedJson = extractJsonFromText(text) {
                print("🟢 \(context): Successfully extracted embedded JSON")
                return Just(extractedJson).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            
            // Strategy 3: Extract JSON from code block
            if let extractedJson = extractJsonFromCodeBlock(text) {
                print("🟢 \(context): Successfully extracted JSON from code block")
                return Just(extractedJson).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            
            // Fallback: No valid JSON found
            print("🔴 \(context): Could not extract JSON from response")
            return Just([:]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
    }
    
    /// Extract JSON from plain text
    /// - Parameter text: Text that may contain JSON
    /// - Returns: Dictionary if successful, nil otherwise
    private func extractJsonFromText(_ text: String) -> [String: Any]? {
        if let jsonStartIndex = text.firstIndex(of: "{"),
           let jsonEndIndex = text.lastIndex(of: "}") {
            let jsonSubstring = text[jsonStartIndex...jsonEndIndex]
            if let jsonData = String(jsonSubstring).data(using: .utf8),
               let extractedJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return extractedJson
            }
        }
        return nil
    }
    
    /// Extract JSON from code block
    /// - Parameter text: Text that may contain code block with JSON
    /// - Returns: Dictionary if successful, nil otherwise
    private func extractJsonFromCodeBlock(_ text: String) -> [String: Any]? {
        if text.contains("```json") || text.contains("```") {
            // Extract JSON from code block format
            let cleanedText = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let jsonData = cleanedText.data(using: .utf8),
               let extractedJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return extractedJson
            }
        }
        return nil
    }
    
    /// Parse date string with multiple format support
    /// - Parameter dateString: Date string to parse
    /// - Returns: Date if successful, nil otherwise
    private func parseDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        // Try multiple date formats
        let dateFormats = ["yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy", "yyyy/MM/dd"]
        
        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    // MARK: - API Communication
    
    /// Send request to Gemini API
    /// - Parameters:
    ///   - model: Model to use
    ///   - body: Request body
    /// - Returns: A publisher that emits a Gemini API response
    private func sendRequest(model: Model, body: GeminiRequest) -> AnyPublisher<GeminiResponse, Error> {
        guard let url = URL(string: "\(baseURL)/\(model.rawValue):generateContent?key=\(apiKey)") else {
            print("🔴 ERROR: Invalid URL constructed")
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                .eraseToAnyPublisher()
        }
        
        print("🟢 Sending request to Gemini API: \(model.rawValue)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(body)
            request.httpBody = jsonData
            
            // Log request size for monitoring
            let requestSizeKB = Double(jsonData.count) / 1024.0
            print("🟢 Request payload size: \(requestSizeKB) KB")
            
            // Check if request is too large
            if requestSizeKB > 20000 { // 20MB limit
                print("🔴 ERROR: Request payload is too large (\(requestSizeKB) KB)")
                return Fail(error: NSError(domain: "GeminiService", code: 413, userInfo: [NSLocalizedDescriptionKey: "Request payload is too large"]))
                    .eraseToAnyPublisher()
            }
        } catch {
            print("🔴 ERROR: Failed to encode request: \(error.localizedDescription)")
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("🔴 ERROR: Invalid response type")
                    throw NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                print("🟢 Received response with status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 429 { // Rate limit exceeded
                    print("🟠 Rate limit exceeded, switching from \(self.currentModel) to alternative model")
                    // Switch to the other model
                    self.toggleModel()
                    throw NSError(domain: "GeminiService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded, retrying with different model"])
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    // Log error response for debugging
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("🔴 API error with status code \(httpResponse.statusCode)")
                    print("🔴 Response body: \(responseString)")
                    
                    // Parse error message if possible
                    var errorMessage = "API error with status code \(httpResponse.statusCode)"
                    if let errorData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let error = errorData["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        errorMessage = message
                    }
                    
                    throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                
                print("🟢 Successful response received")
                return data
            }
            .decode(type: GeminiResponse.self, decoder: JSONDecoder())
            .catch { error -> AnyPublisher<GeminiResponse, Error> in
                if let nsError = error as NSError?, nsError.code == 429 {
                    // Retry with the other model
                    print("🟠 Retrying with model: \(self.currentModel)")
                    return self.sendRequest(model: self.currentModel, body: body)
                } else {
                    print("🔴 Error in request: \(error.localizedDescription)")
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Toggle between models when rate limit is exceeded
    private func toggleModel() {
        // Switch between Flash and Flash-Lite
        currentModel = (currentModel == .flash) ? .flashLite : .flash
        print("🟠 Switched to model: \(currentModel.rawValue)")
    }
}