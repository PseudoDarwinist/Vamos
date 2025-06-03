import Foundation
import Combine

// Error types for Gemini service
enum GeminiError: Error {
    case invalidResponseFormat(String)
    case processingFailed(String)
    case apiError(String)
}

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
    let role: String
    
    init(parts: [GeminiPart], role: String = "user") {
        self.parts = parts
        self.role = role
    }
    
    enum CodingKeys: String, CodingKey {
        case parts
        case role
    }
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
    
    // Add a cancellables property and geminiApiClient at the top of the class (near the apiKey property)
    private var cancellables = Set<AnyCancellable>()
    
    // Simple API client for direct text generation
    private let geminiApiClient = GeminiTextClient()
    
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
    
    // MARK: - Credit Card Statement Processing
    
    /// Process credit card statement text and extract structured data
    /// - Parameter ocrText: Cleaned OCR text from credit card statement
    /// - Returns: A publisher that emits a CreditCardStatement object
    func processCreditCardStatement(ocrText: String) -> AnyPublisher<CreditCardStatement, Error> {
        print("💳 STATEMENT PROCESSING: Starting credit card statement processing")
        
        // Use Flash-Lite model for text processing
        let model = Model.flashLite
        
        // JSON Schema for output validation
        let jsonSchema = """
        {
          "card": {
            "issuer": "string?",
            "product": "string?",
            "last4": "string?",
            "statement_period": {
              "from": "string",
              "to": "string"
            }
          },
          "transactions": [
            {
              "date": "string",
              "description": "string",
              "amount": "number",
              "currency": "string",
              "type": "string",
              "derived": {
                "category": "string?",
                "merchant": "string?"
              }
            }
          ],
          "summary": {
            "total_debits": "number?",
            "total_credits": "number?",
            "currency": "string?"
          }
        }
        """
        
        // Merchant-to-category mapping for Indian merchants
        let merchantCategoryMapping = """
        Use the following MERCHANT→CATEGORY map before any guessing:
        - SWIGGY, RSP*SWIGGY, WWW SWIGGY → "Food & Dining"
        - ZOMATO, DOMINOS, KFC, MCDONALDS → "Food & Dining"
        - STARBUCKS, CHAAYOS, CAFE COFFEE DAY → "Food & Dining"
        - INSTAMART, BIG BASKET, NATURES BASKET → "Groceries"
        - BLINKIT, ZEPTO, DMART, RELIANCE FRESH → "Groceries"
        - LICIOUS, COUNTRY DELIGHT, MILK BASKET → "Groceries"
        - HPCL, IOCL, BHARAT PETROLEUM, SHELL → "Transportation"
        - UBER, OLA, RAPIDO, MERU → "Transportation"
        - IRCTC, RAILWAYS, REDBUS, METRO → "Transportation"
        - AMAZON, FLIPKART, MYNTRA, AJIO → "Shopping"
        - NYKAA, SNAPDEAL, MEESHO, TATA CLIQ → "Shopping"
        - IKEA, PEPPERFRY, H&M, ZARA, LIFESTYLE → "Shopping"
        - APOLLO, MEDPLUS, PHARMACY, NETMEDS → "Healthcare"
        - PHARMEASY, 1MG, TATA 1MG, PRACTO → "Healthcare"
        - HOSPITAL, CLINIC, DIAGNOSTIC, LAB → "Healthcare"
        - AIRTEL, JIO, VODAFONE, VI, BSNL → "Utilities"
        - ELECTRICITY, WATER, GAS, MOBILE, PHONE → "Utilities"
        - NETFLIX, AMAZON PRIME, HOTSTAR, DISNEY → "Entertainment"
        - BOOKMYSHOW, PVR, INOX, CARNIVAL → "Entertainment"
        """
        
        // Create optimized prompt for credit card statement processing
        let textPart = GeminiPart(
            text: """
            You are a financial data extraction engine specializing in credit card statements from Indian banks like SBI, HDFC, ICICI, etc. OUTPUT ONLY valid JSON that conforms exactly to this schema:
            \(jsonSchema)
            
            IMPORTANT: YOUR PRIMARY GOAL IS TO EXTRACT EVERY SINGLE TRANSACTION FROM THE STATEMENT. BE EXTREMELY THOROUGH.
            
            Guidelines:
            1. Pay special attention to transaction tables in the statement. Look for content with dates and amounts in rows.
            2. Extract ALL transactions, even if they have high values (like ₹50,000+).
            3. Amounts are numeric and always positive; use "type": "credit" or "debit" to indicate direction.
            4. For SBI cards: 'C' means credit, 'D' means debit. For HDFC: 'CR' means credit, 'DR' means debit.
            5. Currency is "INR" unless explicitly stated otherwise.
            6. UPI Rule: If description contains "UPI", set the category to "UPI" regardless of what might be inferred.
            7. The statement period is usually found near the top of the document or in header sections.
            8. DO NOT miss high-value transactions. Double-check your extraction by comparing your total with any summary totals in the statement.
            9. For rows with tabular format, check each column carefully to extract the correct date, description, and amount.
            10. CRITICAL: NEVER merge similar-looking transactions! Even if two transactions have the same merchant, date, and similar descriptions, treat them as separate transactions if they appear as separate rows in the statement.
            11. Keep all transactions in the exact order they appear in the statement.
            
            \(merchantCategoryMapping)
            
            The following is raw OCR text from a credit-card statement. Look for transaction tables and extract all rows:
            
            \(ocrText)
            """
        )
        
        // Create request with text prompt
        let content = GeminiContent(parts: [textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        // Send request to Gemini
        return sendRequest(model: model, body: requestBody)
            .tryMap { response -> CreditCardStatement in
                // Extract JSON from response
                guard let text = response.candidates.first?.content.parts.first?.text,
                      let data = text.data(using: .utf8) else {
                    throw NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Gemini API"])
                }
                
                // Parse JSON to CreditCardStatement
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                do {
                    let statement = try decoder.decode(CreditCardStatement.self, from: data)
                    print("💳 STATEMENT PROCESSING: Successfully extracted \(statement.transactions.count) transactions")
                    return statement
                } catch {
                    // Try to extract JSON from text if it's embedded
                    if let extractedJson = self.extractJsonFromText(text),
                       let jsonData = try? JSONSerialization.data(withJSONObject: extractedJson),
                       let statement = try? decoder.decode(CreditCardStatement.self, from: jsonData) {
                        print("💳 STATEMENT PROCESSING: Successfully extracted \(statement.transactions.count) transactions after JSON fix")
                        return statement
                    }
                    
                    print("💳 STATEMENT PROCESSING: Failed to parse JSON - \(error.localizedDescription)")
                    throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response"])
                }
            }
            .mapError { error -> Error in
                print("💳 STATEMENT PROCESSING: Error - \(error.localizedDescription)")
                return error
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
    
    /// Process statement text with Gemini AI (async/await version)
    /// - Parameters:
    ///   - text: The text to process
    ///   - progressCallback: Callback for progress updates
    /// - Returns: The processed statement
    func processStatement(text: String, progressCallback: ((Double) -> Void)? = nil) async throws -> CreditCardStatement {
        print("🤖 GeminiService: Processing statement with Gemini")
        
        // Create a task to allow progress reporting while waiting for the AI
        return try await withCheckedThrowingContinuation { continuation in
            // Report initial progress
            progressCallback?(0.1)
            
            // Build the prompt with the schema
            let prompt = buildPrompt(ocrText: text)
            
            // Report progress after preparing prompt
            progressCallback?(0.3)
            
            // Call Gemini API
            self.geminiApiClient.generateContent(prompt: prompt)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            print("🔴 GeminiService: Error processing statement with Gemini - \(error)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { response in
                        // Report progress after receiving response
                        progressCallback?(0.8)
                        
                        // Log the raw response from Gemini before any cleaning
                        print("🔵 GeminiService: Raw response from API: \(response)")
                        
                        do {
                            // Clean up the response to extract JSON from possible Markdown code blocks
                            let cleanedResponse = self.cleanJsonResponse(response)
                            print("🔄 GeminiService: Cleaned response for parsing")
                            
                            // Parse the JSON response
                            if let jsonData = cleanedResponse.data(using: .utf8) {
                                do {
                                    // Save raw JSON for debugging if needed
                                    print("🟢 GeminiService: Attempting to parse cleaned JSON...")
                                    
                                    let statement = try JSONDecoder().decode(CreditCardStatement.self, from: jsonData)
                                    
                                    // Report progress after parsing
                                    progressCallback?(1.0)
                                    
                                    // Return the statement
                                    continuation.resume(returning: statement)
                                } catch {
                                    print("🔴 GeminiService: Error parsing JSON - \(error.localizedDescription)")
                                    
                                    // Try a different approach with manual JSON parsing
                                    if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                        print("🟠 GeminiService: Trying manual JSON parsing...")
                                        
                                        // Try to manually construct the CreditCardStatement
                                        if let statement = self.manuallyConstructStatement(from: jsonObject) {
                                            progressCallback?(1.0)
                                            continuation.resume(returning: statement)
                                            return
                                        }
                                    }
                                    
                                    // If we get here, both automatic and manual parsing failed
                                    print("🔴 GeminiService: Raw response: \(response.prefix(200))...")
                                    continuation.resume(throwing: error)
                                }
                            } else {
                                throw GeminiError.invalidResponseFormat("Unable to convert response to data")
                            }
                        } catch {
                            print("🔴 GeminiService: Error parsing statement JSON - \(error)")
                            print("🔴 GeminiService: Raw response: \(response.prefix(200))...")
                            continuation.resume(throwing: error)
                        }
                    }
                )
                .store(in: &self.cancellables)
        }
    }
    
    /// Clean JSON response by removing Markdown code block delimiters
    /// - Parameter response: Raw response from Gemini API
    /// - Returns: Cleaned JSON string
    private func cleanJsonResponse(_ response: String) -> String {
        // Extract content from Markdown code blocks
        var cleanedResponse = response
        
        // Check if response is wrapped in Markdown code block
        if response.hasPrefix("```") {
            // Extract content between code block markers
            let lines = response.components(separatedBy: .newlines)
            var cleanedLines: [String] = []
            var insideCodeBlock = false
            
            for line in lines {
                if line.hasPrefix("```") {
                    insideCodeBlock = !insideCodeBlock
                    continue // Skip the code block markers
                }
                
                if insideCodeBlock || !line.hasPrefix("```") {
                    cleanedLines.append(line)
                }
            }
            
            cleanedResponse = cleanedLines.joined(separator: "\n")
        }
        
        // Handle case where the response starts with a single backtick
        if cleanedResponse.hasPrefix("`") {
            cleanedResponse = String(cleanedResponse.dropFirst())
        }
        
        // Additional sanitization to handle common JSON issues
        do {
            // Try to parse it first to see if it's valid JSON
            if let _ = try? JSONSerialization.jsonObject(with: cleanedResponse.data(using: .utf8) ?? Data(), options: []) {
                // If we can parse it, return as is
                return cleanedResponse
            }
            
            // If parsing failed, try to sanitize the JSON
            print("🔶 GeminiService: Initial JSON parsing failed, attempting to sanitize")
            
            // Iteratively remove commas between digits
            var lastPassResponseForCommaRemoval = ""
            var iterationCount = 0
            let maxIterations = 10 // Safety break for the loop

            print("🔶 GeminiService: Starting aggressive comma removal from numbers.")
            while cleanedResponse != lastPassResponseForCommaRemoval && iterationCount < maxIterations {
                lastPassResponseForCommaRemoval = cleanedResponse
                do {
                    let commaBetweenDigitsRegex = try NSRegularExpression(pattern: #"(\d),(\d)"#)
                    cleanedResponse = commaBetweenDigitsRegex.stringByReplacingMatches(in: cleanedResponse,
                                                                                       options: [],
                                                                                       range: NSRange(location: 0, length: (cleanedResponse as NSString).length),
                                                                                       withTemplate: "$1$2")
                } catch {
                    print("🔴 GeminiService: Error creating regex for aggressive comma removal: \(error). Skipping this step.")
                    break // Exit loop on regex error
                }
                iterationCount += 1
            }
            if iterationCount >= maxIterations {
                print("🔶 GeminiService: Max iterations reached for aggressive comma removal.")
            }
            print("🔶 GeminiService: After aggressively removing commas from numbers (iterations: \(iterationCount)): \(cleanedResponse.prefix(1000))...")

            cleanedResponse = cleanedResponse
                .replacingOccurrences(of: "\\u{0000}", with: "")
                .replacingOccurrences(of: "\\u{0001}", with: "")
                .replacingOccurrences(of: "\\u{0002}", with: "")
                .replacingOccurrences(of: "\\u{0003}", with: "")
                .replacingOccurrences(of: "\\u{0004}", with: "")
                .replacingOccurrences(of: "\\u{0005}", with: "")
                .replacingOccurrences(of: "\\u{0006}", with: "")
                .replacingOccurrences(of: "\\u{0007}", with: "")
                .replacingOccurrences(of: "\\u{0008}", with: "")
                .replacingOccurrences(of: ",\n}", with: "\n}")
                .replacingOccurrences(of: ",\n]", with: "\n]")
            
            let keyQuotingRegex = try NSRegularExpression(pattern: #"([{,]\s*)([a-zA-Z0-9_\-\.]+)(\s*:)"#)
            let quote = "\""
            let template = "$1\(quote)$2\(quote)$3"
            cleanedResponse = keyQuotingRegex.stringByReplacingMatches(in: cleanedResponse, options: [], range: NSRange(location: 0, length: cleanedResponse.utf16.count), withTemplate: template)
            
            let numberRegex = try NSRegularExpression(pattern: #"([0-9]+\.[0-9]+)[Ee](\+|-)([0-9]+)"#)
            let nsString = cleanedResponse as NSString
            let scientificNotationRange = NSRange(location: 0, length: nsString.length)
            let scientificMatches = numberRegex.matches(in: cleanedResponse, range: scientificNotationRange)
            
            for match in scientificMatches.reversed() {
                if match.numberOfRanges == 4 {
                    let baseNumberRange = match.range(at: 1)
                    let signRange = match.range(at: 2)
                    let exponentRange = match.range(at: 3)
                    
                    if baseNumberRange.location != NSNotFound && signRange.location != NSNotFound && exponentRange.location != NSNotFound {
                        let baseNumber = nsString.substring(with: baseNumberRange)
                        let sign = nsString.substring(with: signRange)
                        let exponent = nsString.substring(with: exponentRange)
                        
                        if let baseValue = Double(baseNumber), let exponentValue = Int(exponent) {
                            let multiplier = sign == "+" ? pow(10, Double(exponentValue)) : 1.0 / pow(10, Double(exponentValue))
                            let newValue = baseValue * multiplier
                            let formatter = NumberFormatter()
                            formatter.numberStyle = .decimal
                            formatter.maximumFractionDigits = 20
                            formatter.usesGroupingSeparator = false
                            if let formattedNumber = formatter.string(from: NSNumber(value: newValue)) {
                                cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: match.range, with: formattedNumber)
                            }
                        }
                    }
                }
            }

            // Try to parse the sanitized JSON
            if let _ = try? JSONSerialization.jsonObject(with: cleanedResponse.data(using: .utf8) ?? Data(), options: []) {
                print("🟢 GeminiService: JSON sanitization successful after targeted fixes.")
                return cleanedResponse
            } else {
                print("🔴 GeminiService: JSON sanitization failed even after targeted fixes, trying fallback.")
                
                if let data = cleanedResponse.data(using: .utf8) {
                    do {
                        _ = try JSONSerialization.jsonObject(with: data, options: [])
                    } catch let error as NSError {
                        if let debugDescription = error.userInfo["NSDebugDescription"] as? String,
                           let errorIndex = error.userInfo["NSJSONSerializationErrorIndex"] as? Int {
                            
                            print("🔶 GeminiService: JSON error at index \(errorIndex): \(debugDescription)")
                            
                            if errorIndex > 0 && errorIndex < cleanedResponse.count {
                                let index = cleanedResponse.index(cleanedResponse.startIndex, offsetBy: errorIndex)
                                let startIndex = cleanedResponse.index(index, offsetBy: -10, limitedBy: cleanedResponse.startIndex) ?? cleanedResponse.startIndex
                                let endIndex = cleanedResponse.index(index, offsetBy: 10, limitedBy: cleanedResponse.endIndex) ?? cleanedResponse.endIndex
                                let problematicSegment = cleanedResponse[startIndex..<endIndex]
                                print("🔶 GeminiService: Problematic segment around error: \(problematicSegment)")

                                // Fallback: try removing the character at the error index
                                var mutableChars = Array(cleanedResponse)
                                if mutableChars.indices.contains(errorIndex) {
                                    let removedChar = mutableChars.remove(at: errorIndex)
                                    print("🔶 GeminiService: Fallback - removed character '\(removedChar)' at index \(errorIndex).")
                                    let potentiallyFixedResponse = String(mutableChars)
                                    if let fixedData = potentiallyFixedResponse.data(using: .utf8),
                                       let _ = try? JSONSerialization.jsonObject(with: fixedData, options: []) {
                                        print("🟢 GeminiService: Successfully fixed JSON by removing character at error index.")
                                        return potentiallyFixedResponse
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("🔴 GeminiService: Error during JSON sanitization: \(error)")
        }
        
        print("🔴 GeminiService: Returning cleanedResponse as is, as all parsing attempts failed.")
        return cleanedResponse
    }
    
    /// Manually construct a CreditCardStatement from a dictionary
    /// - Parameter json: Dictionary parsed from JSON
    /// - Returns: CreditCardStatement if successful, nil otherwise
    private func manuallyConstructStatement(from json: [String: Any]) -> CreditCardStatement? {
        // Create empty statement to populate
        var statement = CreditCardStatement(
            card: CardInfo(issuer: "Unknown", last4: nil, statementPeriod: nil),
            transactions: [],
            summary: nil
        )
        
        // Try to parse card info
        if let cardDict = json["card"] as? [String: Any] {
            let issuer = cardDict["issuer"] as? String ?? cardDict["name"] as? String ?? "Unknown"
            let last4: String? = cardDict["last4"] as? String
            let number = cardDict["number"] as? String
            
            // Extract last 4 digits from card number if available
            let extractedLast4: String? = if let num = number, num.count >= 4 {
                String(num.suffix(4))
            } else {
                nil
            }
            
            var period: StatementPeriod? = nil
            if let periodDict = cardDict["statementPeriod"] as? [String: String] ?? cardDict["statement_period"] as? [String: String] {
                period = StatementPeriod(
                    from: periodDict["from"] ?? "",
                    to: periodDict["to"] ?? ""
                )
            }
            
            statement.card = CardInfo(
                issuer: issuer,
                product: cardDict["product"] as? String,
                last4: last4 ?? extractedLast4,
                statementPeriod: period
            )
        }
        
        // Try to parse summary
        if let summaryDict = json["summary"] as? [String: Any] {
            let totalSpend = self.decimalFromAny(summaryDict["totalSpend"] ?? summaryDict["total_spend"] ?? summaryDict["total_debits"])
            let openingBalance = self.decimalFromAny(summaryDict["openingBalance"] ?? summaryDict["opening_balance"])
            let closingBalance = self.decimalFromAny(summaryDict["closingBalance"] ?? summaryDict["closing_balance"])
            let minPayment = self.decimalFromAny(summaryDict["minPayment"] ?? summaryDict["min_payment"])
            
            statement.summary = StatementSummary(
                totalSpend: totalSpend,
                openingBalance: openingBalance,
                closingBalance: closingBalance,
                minPayment: minPayment,
                dueDate: summaryDict["dueDate"] as? String ?? summaryDict["due_date"] as? String
            )
        }
        
        // Try to parse transactions
        if let transactionsArray = json["transactions"] as? [[String: Any]] {
            var transactions: [StatementTransaction] = []
            
            for transDict in transactionsArray {
                // Required fields
                guard let dateString = transDict["date"] as? String,
                      let description = transDict["description"] as? String else {
                    continue
                }
                
                let amount = self.decimalFromAny(transDict["amount"]) ?? 0
                let typeString = transDict["type"] as? String ?? "debit"
                let type: TransactionType = typeString.lowercased().contains("credit") ? .credit : .debit
                let currency = transDict["currency"] as? String ?? "INR"
                
                // Derived fields
                var derived: DerivedInfo? = nil
                if let derivedDict = transDict["derived"] as? [String: Any] {
                    // Parse foreign exchange info if available
                    var fx: ForeignExchange? = nil
                    if let fxDict = derivedDict["fx"] as? [String: Any] {
                        let originalAmount = self.decimalFromAny(fxDict["originalAmount"] ?? fxDict["original_amount"])
                        let originalCurrency = fxDict["originalCurrency"] as? String ?? fxDict["original_currency"] as? String
                        
                        if let amount = originalAmount, let currency = originalCurrency {
                            fx = ForeignExchange(
                                originalAmount: amount,
                                originalCurrency: currency
                            )
                        }
                    }
                    
                    derived = DerivedInfo(
                        category: derivedDict["category"] as? String,
                        merchant: derivedDict["merchant"] as? String,
                        isRecurring: derivedDict["isRecurring"] as? Bool ?? derivedDict["is_recurring"] as? Bool,
                        fx: fx
                    )
                }
                
                // Create transaction and add to array
                let transaction = StatementTransaction(
                    date: dateString,
                    description: description,
                    amount: amount,
                    currency: currency,
                    type: type,
                    derived: derived
                )
                
                transactions.append(transaction)
            }
            
            statement.transactions = transactions
        }
        
        // Return nil if we couldn't parse any transactions
        return statement.transactions.isEmpty ? nil : statement
    }
    
    /// Convert various types to Decimal
    /// - Parameter value: Any value that might represent a number
    /// - Returns: Decimal if conversion is possible, nil otherwise
    private func decimalFromAny(_ value: Any?) -> Decimal? {
        if let decimal = value as? Decimal {
            return decimal
        } else if let double = value as? Double {
            return Decimal(double)
        } else if let int = value as? Int {
            return Decimal(int)
        } else if let stringValue = value as? String {
            // Create a NumberFormatter that uses '.' as the decimal separator
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX") // Ensures '.' is decimal separator
            formatter.numberStyle = .decimal
            if let number = formatter.number(from: stringValue) {
                return number.decimalValue
            } else if let double = Double(stringValue) { // Fallback for simple double strings without locale issues
                 return Decimal(double)
            }
        } else if let nsNumber = value as? NSNumber {
            return Decimal(string: "\(nsNumber)") ?? Decimal(nsNumber.doubleValue)
        }
        return nil
    }
    
    /// Build the prompt for statement processing
    /// - Parameter ocrText: Text from OCR to process
    /// - Returns: A formatted prompt string
    private func buildPrompt(ocrText: String) -> String {
        // Create a prompt with schema information and OCR text
        return """
        You are a specialized financial document parser for Indian credit card statements from banks like SBI, HDFC, ICICI, Axis, etc.
        
        YOUR ABSOLUTE PRIORITY: Extract EVERY SINGLE TRANSACTION with 100% ACCURACY. Each row in the transaction table MUST become one transaction in your output.
        
        ⚠️ CRITICAL TABLE PARSING WARNING ⚠️
        The most common error is MISALIGNING data from different columns/rows. You MUST ensure that each transaction's date, description, and amount come from the SAME ROW in the table.
        
        Output ONLY valid JSON conforming to this schema:
        {
            "card": {
                "name": "string", // e.g., "SBI Card", "HDFC Bank Credit Card"
                "number": "string", // Masked card number, e.g., "XXXX XXXX XXXX 1234"
                "statementPeriod": {
                    "from": "YYYY-MM-DD",
                    "to": "YYYY-MM-DD"
                }
            },
            "summary": {
                "totalSpend": number, // Sum of all debit transactions
                "openingBalance": number,
                "closingBalance": number,
                "minPayment": number,
                "dueDate": "YYYY-MM-DD"
            },
            "transactions": [
                {
                    "date": "YYYY-MM-DD",
                    "description": "string", // EXACT merchant/description as it appears
                    "amount": number, // Always positive, exact amount from statement
                    "type": "debit" | "credit", // "debit" for purchases/charges, "credit" for payments/refunds
                    "category": "string" // Best guess: UPI, Food, Shopping, Fuel, etc.
                }
            ]
        }

        🔍 **STEP-BY-STEP TABLE PARSING PROCESS:**
        
        **STEP 1: IDENTIFY THE TRANSACTION TABLE**
        - Look for tabular data with columns like: Date | Description | Amount | Type
        - Common headers: "Date", "Transaction Details", "Amount", "Cr/Dr" or "C/D"
        - The table usually appears after summary information
        
        **STEP 2: IDENTIFY COLUMN STRUCTURE**
        - Examine the first few rows to understand column positions
        - Typical format: "DATE | DESCRIPTION | AMOUNT | TYPE"
        - Note any separators (|, spaces, tabs) used between columns
        
        **STEP 3: PROCESS EACH ROW INDIVIDUALLY**
        - Go through the table line by line
        - For EACH row, identify which text belongs to which column
        - NEVER take the description from one row and amount from another row
        - NEVER skip rows or merge data from different rows
        
        **STEP 4: VALIDATE ROW DATA**
        Before adding each transaction, verify:
        - Does the date make sense? (should be within statement period)
        - Does the amount look reasonable? (positive number)
        - Does the description match the amount? (small amounts shouldn't have luxury descriptions)
        
        🔍 **PRECISE DATA EXTRACTION RULES:**
        
        📅 **DATE EXTRACTION:**
        - Convert "DD MMM YY" to "YYYY-MM-DD" (e.g., "27 Mar 25" → "2025-03-27")
        - If date appears to be wrong, double-check which column it came from
        
        📝 **DESCRIPTION EXTRACTION:**
        - Use EXACT text from the description column
        - Do NOT mix descriptions from different rows
        - Common patterns: "UPI-MERCHANT NAME", "SWIGGY ORDER", "AMAZON.IN"
        - If description seems too long, it might include data from next column
        
        💰 **AMOUNT EXTRACTION:**
        - Extract EXACT numerical value from amount column
        - Remove currency symbols: 3,845.64 → 3845.64, 26,560.00 → 26560.00
        - If amount seems unrealistic for the description, re-check column alignment
        
        🏷️ **TYPE DETERMINATION:**
        - SBI Cards: "C" = credit, "D" = debit
        - HDFC Cards: "CR" = credit, "DR" = debit
        - ICICI Cards: "Cr" = credit, "Dr" = debit
        
        ⚠️ **COMMON MISALIGNMENT ERRORS TO AVOID:**
        
        1. **Description-Amount Mismatch:**
            ❌ WRONG: "UPI-Tea/Coffee Shop" with amount 25000.00 (amount too high for small purchase)
            ✅ CORRECT: "UPI-Tea/Coffee Shop" with amount 120.00
        
        2. **Row Skipping:**
            ❌ WRONG: Missing a transaction row entirely
            ✅ CORRECT: Every visible row becomes a transaction
        
        3. **Column Drift:**
            ❌ WRONG: Taking description from column 2, but amount from column 4 of next row
            ✅ CORRECT: All data for one transaction comes from the same row
        
        4. **Data Merging:**
            ❌ WRONG: Combining "UPI-MERCHANT A" and "UPI-MERCHANT B" into one transaction
            ✅ CORRECT: Each merchant is a separate transaction
        
        🔍 **VERIFICATION CHECKLIST:**
        After extracting each transaction, ask yourself:
        - Does this combination of description + amount make logical sense?
        - Is this amount reasonable for this merchant/description?
        - Did I take all data from the same row?
        - Are there any obvious mismatches (tiny amounts for expensive items, etc.)?
        
        📊 **TABLE PARSING EXAMPLE:**
        If you see a table like:
        ```
        DD MMM YY  |  TRANSACTION DESCRIPTION     |  AMOUNT  |  TYPE
        05 Mar 25  |  UPI-MERCHANT NAME          |  XXX.XX  |  D
        06 Mar 25  |  STORE/WEBSITE NAME         |  XXX.XX  |  D  
        07 Mar 25  |  UPI-ANOTHER MERCHANT       |  XXX.XX  |  D
        ```
        
        Extract each row as a separate transaction:
        1. date: "2025-03-05", description: "UPI-MERCHANT NAME", amount: XXX.XX
        2. date: "2025-03-06", description: "STORE/WEBSITE NAME", amount: XXX.XX
        3. date: "2025-03-07", description: "UPI-ANOTHER MERCHANT", amount: XXX.XX
        
        NEVER mix data from different rows - each row is one complete transaction.
        
        🏷️ **CATEGORY CLASSIFICATION:**
        - UPI transactions: "UPI" (if description contains "UPI")
        - Food delivery: "Food" (Swiggy, Zomato, restaurants, cafes)
        - Fuel stations: "Fuel" (Bharat Petroleum, Indian Oil, HP, Shell)
        - Groceries: "Groceries" (BigBasket, Instamart, D-Mart, local grocery stores)
        - Shopping: "Shopping" (Amazon, Flipkart, Myntra)
        - Payments: "Payment" (PAYMENT RECEIVED, NEFT, RTGS)
        
        💯 **FINAL QUALITY CHECK:**
        Before outputting JSON:
        1. Count visible transaction rows in the statement
        2. Count transactions in your JSON output
        3. These numbers should match exactly
        4. Scan for obviously wrong amount-description pairs
        5. Verify high-value transactions are legitimate (not parsing errors)
        
        Now extract ALL transactions from this Indian credit card statement, being extremely careful about table column alignment:

        \(ocrText)
        """
    }
}

// MARK: - GeminiTextClient
/// Simple client for text generation using Gemini API
class GeminiTextClient {
    // API key
    private let apiKey = "AIzaSyD_49Jhf8WZ4irHzaK8KqiEHOw-ILQ3Cow"
    private let baseURL = "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent"
    
    /// Generate content using Gemini
    /// - Parameter prompt: Text prompt
    /// - Returns: Publisher with response string
    func generateContent(prompt: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            return Fail(error: GeminiError.apiError("Invalid URL"))
                .eraseToAnyPublisher()
        }
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ],
                    "role": "user"
                ]
            ]
        ]
        
        // Serialize to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return Fail(error: GeminiError.apiError("Failed to serialize request"))
                .eraseToAnyPublisher()
        }
        
        request.httpBody = jsonData
        
        // Send the request
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiError.apiError("Invalid response")
                }
                
                guard (200..<300).contains(httpResponse.statusCode) else {
                    // Try to extract error message from response
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        throw GeminiError.apiError(message)
                    }
                    
                    throw GeminiError.apiError("API error: HTTP \(httpResponse.statusCode)")
                }
                
                return data
            }
            .tryMap { (data: Data) in
                // Parse the response
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let firstPart = parts.first,
                      let text = firstPart["text"] as? String else {
                    throw GeminiError.invalidResponseFormat("Invalid response format")
                }
                
                return text
            }
            .eraseToAnyPublisher()
    }
}