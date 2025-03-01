import Foundation
import Combine

// Updated Response models for Gemini API
struct GeminiResponse: Codable {
    let candidates: [Candidate]
    let promptFeedback: PromptFeedback?
}

struct Candidate: Codable {
    let content: Content
    let finishReason: String?
    // Remove 'index' property since it's not in the API response
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
    // API key should ideally be stored in a secure location or environment variable
    private let apiKey = "AIzaSyD_49Jhf8WZ4irHzaK8KqiEHOw-ILQ3Cow"
    private let baseURL = "https://generativelanguage.googleapis.com/v1"
    
    // Updated model names based on Gemini 2.0 models
    private enum Model: String {
        case flash = "models/gemini-2.0-flash"
        case flashLite = "models/gemini-2.0-flash-lite"
    }
    
    // Use the full-featured model for image processing by default
    private var currentModel: Model = .flash
    
    // Method to extract information from receipt image
    func extractReceiptInfo(imageData: Data) -> AnyPublisher<[String: Any], Error> {
        print("🟢 GeminiService: Starting extractReceiptInfo")
        
        // Check if image data is valid
        if imageData.isEmpty {
            print("🔴 GeminiService: Image data is empty")
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Image data is empty"]))
                .eraseToAnyPublisher()
        }
        
        // Log image data size
        let imageSizeKB = Double(imageData.count) / 1024.0
        print("🟢 GeminiService: Image data size: \(imageSizeKB) KB")
        
        // Check if image is too large for API
        if imageSizeKB > 10240 { // 10MB limit for most APIs
            print("🔴 GeminiService: Image is too large for API (\(imageSizeKB) KB)")
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Image is too large for API"]))
                .eraseToAnyPublisher()
        }
        
        // Convert image data to base64
        let base64String = imageData.base64EncodedString()
        
        // Check if base64 string is valid
        if base64String.isEmpty {
            print("🔴 GeminiService: Failed to convert image to base64")
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to base64"]))
                .eraseToAnyPublisher()
        }
        
        print("🟢 GeminiService: Successfully converted image to base64 (length: \(base64String.count))")
        
        // Use Flash for multimodal capabilities (image processing)
        // Gemini 2.0 Flash supports images, audio, video, and text inputs
        let imageModel = Model.flash
        
        // Create two separate parts: first for the image, second for the text prompt
        let imagePart = GeminiPart(
            inlineData: GeminiInlineData(
                mimeType: "image/jpeg",
                data: base64String
            )
        )
        
        let textPart = GeminiPart(
            text: """
            Extract the following information from this receipt image:
            - date (in format YYYY-MM-DD)
            - merchant_name (the store or business name)
            - total_amount (just the number, without currency symbol)
            - category (e.g., Groceries, Dining, Transportation)
            
            Format the response as a JSON object with these exact keys.
            If you cannot find a specific piece of information, use null for that field.
            """
        )
        
        // Add both parts to the content
        let content = GeminiContent(parts: [imagePart, textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: imageModel, body: requestBody)
            .map { response -> [String: Any] in
                guard let text = response.candidates.first?.content.parts.first?.text,
                      let data = text.data(using: .utf8) else {
                    print("🔴 GeminiService: No text in response or failed to convert to data")
                    return [:]
                }
                
                print("🟢 GeminiService: Received text response: \(text)")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("🟢 GeminiService: Successfully parsed JSON response")
                        return json
                    } else {
                        print("🔴 GeminiService: Response is not a valid JSON object")
                        
                        // Try to extract JSON from text if it's embedded in other text
                        if let jsonStartIndex = text.firstIndex(of: "{"),
                           let jsonEndIndex = text.lastIndex(of: "}") {
                            let jsonSubstring = text[jsonStartIndex...jsonEndIndex]
                            if let jsonData = String(jsonSubstring).data(using: .utf8),
                               let extractedJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                                print("🟢 GeminiService: Successfully extracted embedded JSON")
                                return extractedJson
                            }
                        }
                        
                        return [:]
                    }
                } catch {
                    print("🔴 GeminiService: Error parsing JSON: \(error)")
                    
                    // Handle the case where JSON is wrapped in backticks
                    if text.contains("```json") {
                        // Extract JSON from code block format
                        let cleanedText = text.replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        print("🟢 GeminiService: Attempting to parse JSON from code block: \(cleanedText)")
                        
                        if let jsonData = cleanedText.data(using: .utf8),
                           let extractedJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            print("🟢 GeminiService: Successfully extracted JSON from code block")
                            return extractedJson
                        }
                    }
                    
                    return [:]
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Method to generate narrative summary
    func generateNarrativeSummary(transactions: [Transaction]) -> AnyPublisher<String, Error> {
        print("🟢 GeminiService: Starting generateNarrativeSummary")
        
        // Use Flash-Lite for simple text generation (more cost-efficient)
        let textModel = Model.flashLite
        
        // Create a description of the transactions for the prompt
        var transactionDescriptions = ""
        for transaction in transactions {
            transactionDescriptions += "- \(transaction.merchant): $\(transaction.amount) on \(transaction.date.relativeDescription()) in category \(transaction.category.name)\n"
        }
        
        let part = GeminiPart(
            text: """
            Based on the following transactions, generate a friendly, nature-themed summary of spending habits:
            
            \(transactionDescriptions)
            
            Keep the response conversational, use plant growth metaphors, and limit to 2-3 sentences.
            """
        )
        
        let content = GeminiContent(parts: [part])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: textModel, body: requestBody)
            .map { response -> String in
                guard let text = response.candidates.first?.content.parts.first?.text else {
                    print("🔴 GeminiService: No text in narrative response")
                    return "Your spending patterns are growing steadily. Keep nurturing your financial garden!"
                }
                print("🟢 GeminiService: Successfully generated narrative")
                return text
            }
            .eraseToAnyPublisher()
    }
    
    // Method to answer user queries about spending
    func answerSpendingQuery(query: String, transactions: [Transaction]) -> AnyPublisher<String, Error> {
        print("🟢 GeminiService: Starting answerSpendingQuery")
        
        // Use Flash for more complex analysis and reasoning
        let textModel = Model.flash
        
        // Create a description of the transactions for the prompt
        var transactionDescriptions = ""
        for transaction in transactions {
            transactionDescriptions += "- \(transaction.merchant): $\(transaction.amount) on \(transaction.date.relativeDescription()) in category \(transaction.category.name)\n"
        }
        
        let part = GeminiPart(
            text: """
            Here are my recent transactions:
            
            \(transactionDescriptions)
            
            Given the above data, answer this question in a friendly, nature-themed way: "\(query)"
            Keep the response conversational, using plant/nature metaphors when relevant, and limit to 3-4 sentences.
            """
        )
        
        let content = GeminiContent(parts: [part])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: textModel, body: requestBody)
            .map { response -> String in
                guard let text = response.candidates.first?.content.parts.first?.text else {
                    print("🔴 GeminiService: No text in query response")
                    return "I couldn't analyze your spending right now. Let's try again later when your financial garden is ready for review."
                }
                print("🟢 GeminiService: Successfully answered query")
                return text
            }
            .eraseToAnyPublisher()
    }
    
    // Private method to send request to Gemini API
    private func sendRequest(model: Model, body: GeminiRequest) -> AnyPublisher<GeminiResponse, Error> {
        guard let url = URL(string: "\(baseURL)/\(model.rawValue):generateContent?key=\(apiKey)") else {
            print("🔴 Error: Invalid URL constructed")
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                .eraseToAnyPublisher()
        }
        
        print("🟢 Sending request to Gemini API: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(body)
            request.httpBody = jsonData
            
            // Log request size
            let requestSizeKB = Double(jsonData.count) / 1024.0
            print("🟢 Request payload size: \(requestSizeKB) KB")
            
            // Check if request is too large
            if requestSizeKB > 20000 { // 20MB is a common limit
                print("🔴 Error: Request payload is too large (\(requestSizeKB) KB)")
                return Fail(error: NSError(domain: "GeminiService", code: 413, userInfo: [NSLocalizedDescriptionKey: "Request payload is too large"]))
                    .eraseToAnyPublisher()
            }
            
            // Check if image data is present and log its size
            if let imagePart = body.contents.first?.parts.first?.inlineData {
                let imageDataSize = Double(Data(base64Encoded: imagePart.data)?.count ?? 0) / 1024.0
                print("🟢 Image data size: \(imageDataSize) KB, MIME type: \(imagePart.mimeType)")
            }
            
            // Log a sample of the request for debugging
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let truncatedJson = jsonString.count > 200 ?
                    jsonString.prefix(100) + "..." + jsonString.suffix(100) :
                    jsonString
                print("🟢 Request JSON (truncated): \(truncatedJson)")
            }
        } catch {
            print("🔴 Error encoding request: \(error.localizedDescription)")
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("🔴 Error: Invalid response type")
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
                    // Log the error response body for debugging
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("🔴 API error with status code \(httpResponse.statusCode)")
                    print("🔴 Response body: \(responseString)")
                    
                    // Parse error response if possible
                    var errorMessage = "API error with status code \(httpResponse.statusCode)"
                    if let errorData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let error = errorData["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        errorMessage = message
                        print("🔴 Detailed error message: \(message)")
                    }
                    
                    // Handle specific error codes
                    switch httpResponse.statusCode {
                    case 400:
                        print("🔴 Bad Request (400): Check API key, request format, or image format")
                    case 401:
                        print("🔴 Unauthorized (401): API key is invalid or missing")
                    case 403:
                        print("🔴 Forbidden (403): API key doesn't have permission")
                    case 404:
                        print("🔴 Not Found (404): Endpoint or model not found")
                    case 413:
                        print("🔴 Payload Too Large (413): Request body is too large")
                    default:
                        print("🔴 Other error: \(httpResponse.statusCode)")
                    }
                    
                    throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                
                // Log successful response
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
    
    // Toggle between models when rate limit is exceeded
    private func toggleModel() {
        // Switch between Flash and Flash-Lite
        currentModel = (currentModel == .flash) ? .flashLite : .flash
        print("🟠 Switched to model: \(currentModel.rawValue)")
    }

    // Method to extract information from PDF document
    func extractPDFInfo(pdfData: Data) -> AnyPublisher<[String: Any], Error> {
        print("🟢 GeminiService: Starting extractPDFInfo")
        
        // Use Flash for complex document analysis
        let pdfModel = Model.flash
        
        // Convert PDF data to base64
        let base64String = pdfData.base64EncodedString()
        
        // Log PDF data size
        let pdfSizeKB = Double(pdfData.count) / 1024.0
        print("🟢 GeminiService: PDF data size: \(pdfSizeKB) KB")
        
        // Create request body with separate parts
        let pdfPart = GeminiPart(
            inlineData: GeminiInlineData(
                mimeType: "application/pdf",
                data: base64String
            )
        )
        
        let textPart = GeminiPart(
            text: """
            Extract the following information from this invoice/receipt PDF:
            1. Date of purchase (format as YYYY-MM-DD)
            2. Merchant/vendor name
            3. Total amount paid (numeric value only)
            4. Tax amount (if available)
            5. Item category (e.g., Fuel, Food, Electronics)
            6. Individual items with prices (if available)
            7. Payment method (if available)
            
            For fuel/petrol receipts, also extract:
            - Fuel type
            - Quantity of fuel
            - Price per unit
            - Vehicle information (if available)
            
            Format the response as a clean, structured JSON object with these exact keys:
            {
              "date": "YYYY-MM-DD",
              "merchant_name": "Store Name",
              "total_amount": "123.45",
              "tax_amount": "10.00",
              "category": "Category Name",
              "items": [{"name": "Item 1", "price": "10.00"}, ...],
              "payment_method": "Credit Card"
            }
            
            If information is not found, use null for that field.
            """
        )
        
        let content = GeminiContent(parts: [pdfPart, textPart])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: pdfModel, body: requestBody)
            .map { response -> [String: Any] in
                guard let text = response.candidates.first?.content.parts.first?.text,
                    let data = text.data(using: .utf8) else {
                    print("🔴 GeminiService: No text in PDF response")
                    return [:]
                }
                
                print("🟢 GeminiService: Received PDF text response")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("🟢 GeminiService: Successfully parsed PDF JSON response")
                        return json
                    } else {
                        print("🔴 GeminiService: PDF response is not a valid JSON object")
                        
                        // Try to extract JSON from text if it's embedded in other text
                        if let jsonStartIndex = text.firstIndex(of: "{"),
                           let jsonEndIndex = text.lastIndex(of: "}") {
                            let jsonSubstring = text[jsonStartIndex...jsonEndIndex]
                            if let jsonData = String(jsonSubstring).data(using: .utf8),
                               let extractedJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                                print("🟢 GeminiService: Successfully extracted embedded JSON from PDF response")
                                return extractedJson
                            }
                        }
                        
                        return [:]
                    }
                } catch {
                    print("🔴 GeminiService: Error parsing PDF JSON: \(error)")
                    
                    // Handle the case where JSON is wrapped in backticks
                    if text.contains("```json") {
                        // Extract JSON from code block format
                        let cleanedText = text.replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        print("🟢 GeminiService: Attempting to parse JSON from code block: \(cleanedText)")
                        
                        if let jsonData = cleanedText.data(using: .utf8),
                           let extractedJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            print("🟢 GeminiService: Successfully extracted JSON from code block")
                            return extractedJson
                        }
                    }
                    
                    return [:]
                }
            }
            .eraseToAnyPublisher()
    }
}
