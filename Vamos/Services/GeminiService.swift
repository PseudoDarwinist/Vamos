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
    private let apiKey = "AIzaSyD_49Jhf8WZ4irHzaK8KqiEHOw-ILQ3Cow"
    private let baseURL = "https://generativelanguage.googleapis.com/v1"
    
    private enum Model: String {
        case flash = "models/gemini-2.0-flash"
        case flashLite = "models/gemini-2.0-flash-lite"
    }
    
    private var currentModel: Model = .flash
    
    // Method to extract information from receipt image
    func extractReceiptInfo(imageData: Data) -> AnyPublisher<[String: Any], Error> {
        // Convert image data to base64
        let base64String = imageData.base64EncodedString()
        
        // Create request body
        let part = GeminiPart(
            text: "Extract the following information from this receipt: date, merchant name, total amount, and item categories. Format the response as a JSON object.",
            inlineData: GeminiInlineData(
                mimeType: "image/jpeg",
                data: base64String
            )
        )
        
        let content = GeminiContent(parts: [part])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: currentModel, body: requestBody)
            .map { response -> [String: Any] in
                guard let text = response.candidates.first?.content.parts.first?.text,
                      let data = text.data(using: .utf8) else {
                    return [:]
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        return json
                    } else {
                        return [:]
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                    return [:]
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Method to generate narrative summary
    func generateNarrativeSummary(transactions: [Transaction]) -> AnyPublisher<String, Error> {
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
        
        return sendRequest(model: currentModel, body: requestBody)
            .map { response -> String in
                guard let text = response.candidates.first?.content.parts.first?.text else {
                    return "Your spending patterns are growing steadily. Keep nurturing your financial garden!"
                }
                return text
            }
            .eraseToAnyPublisher()
    }
    
    // Method to answer user queries about spending
    func answerSpendingQuery(query: String, transactions: [Transaction]) -> AnyPublisher<String, Error> {
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
        
        return sendRequest(model: currentModel, body: requestBody)
            .map { response -> String in
                guard let text = response.candidates.first?.content.parts.first?.text else {
                    return "I couldn't analyze your spending right now. Let's try again later when your financial garden is ready for review."
                }
                return text
            }
            .eraseToAnyPublisher()
    }
    
    // Private method to send request to Gemini API
    private func sendRequest(model: Model, body: GeminiRequest) -> AnyPublisher<GeminiResponse, Error> {
        guard let url = URL(string: "\(baseURL)/\(model.rawValue):generateContent?key=\(apiKey)") else {
            return Fail(error: NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                if httpResponse.statusCode == 429 { // Rate limit exceeded
                    // Switch to the other model
                    self.toggleModel()
                    throw NSError(domain: "GeminiService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded, retrying with different model"])
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error with status code \(httpResponse.statusCode)"])
                }
                
                return data
            }
            .decode(type: GeminiResponse.self, decoder: JSONDecoder())
            .catch { error -> AnyPublisher<GeminiResponse, Error> in
                if let nsError = error as NSError?, nsError.code == 429 {
                    // Retry with the other model
                    return self.sendRequest(model: self.currentModel, body: body)
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Toggle between models when rate limit is exceeded
    private func toggleModel() {
        currentModel = (currentModel == .flash) ? .flashLite : .flash
    }



    // Method to extract information from PDF document
    func extractPDFInfo(pdfData: Data) -> AnyPublisher<[String: Any], Error> {
        // Convert PDF data to base64
        let base64String = pdfData.base64EncodedString()
        
        // Create request body with PDF-specific prompt
        let part = GeminiPart(
            text: """
            Extract the following information from this invoice/receipt PDF:
            1. Date of purchase
            2. Merchant/vendor name
            3. Total amount paid
            4. Tax amount (if available)
            5. Item category (e.g., Fuel, Food, Electronics)
            6. Individual items with prices (if available)
            7. Payment method (if available)
            
            For fuel/petrol receipts, also extract:
            - Fuel type
            - Quantity of fuel
            - Price per unit
            - Vehicle information (if available)
            
            Format the response as a clean, structured JSON object.
            If information is not found, use null for that field.
            """,
            inlineData: GeminiInlineData(
                mimeType: "application/pdf",
                data: base64String
            )
        )
        
        let content = GeminiContent(parts: [part])
        let requestBody = GeminiRequest(contents: [content])
        
        return sendRequest(model: currentModel, body: requestBody)
            .map { response -> [String: Any] in
                guard let text = response.candidates.first?.content.parts.first?.text,
                    let data = text.data(using: .utf8) else {
                    return [:]
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        return json
                    } else {
                        return [:]
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                    return [:]
                }
            }
            .eraseToAnyPublisher()
    }
    
}
