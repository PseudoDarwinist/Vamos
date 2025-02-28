import Foundation
import Vision
import UIKit
import Combine

class OCRService {
    private let geminiService = GeminiService()
    
    // Process image using local Vision framework
    func processReceiptImage(_ image: UIImage) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            guard let cgImage = image.cgImage else {
                promise(.failure(NSError(domain: "OCRService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from UIImage"])))
                return
            }
            
            // Create Vision request
            let request = VNRecognizeTextRequest { (request, error) in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    promise(.failure(NSError(domain: "OCRService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])))
                    return
                }
                
                // Extract text from observations
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                promise(.success(recognizedText))
            }
            
            // Configure the request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            // Process the image
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Extract structured data from receipt
    func extractStructuredData(from image: UIImage) -> AnyPublisher<[String: Any], Error> {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: NSError(domain: "OCRService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"]))
                .eraseToAnyPublisher()
        }
        
        return geminiService.extractReceiptInfo(imageData: imageData)
    }
    
    // Process receipt and return Transaction object
    func processReceipt(image: UIImage) -> AnyPublisher<Transaction, Error> {
        return extractStructuredData(from: image)
            .map { data -> Transaction in
                // Parse extracted data
                let amount = Decimal(string: (data["total_amount"] as? String) ?? "0.0") ?? 0.0
                
                let dateString = data["date"] as? String ?? ""
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let date = dateFormatter.date(from: dateString) ?? Date()
                
                let merchant = data["merchant_name"] as? String ?? "Unknown Merchant"
                let categoryName = data["category"] as? String ?? "Miscellaneous"
                
                // Create Transaction object
                return Transaction(
                    amount: amount,
                    date: date,
                    merchant: merchant,
                    category: Category.sample(name: categoryName),
                    sourceType: .scanned
                )
            }
            .eraseToAnyPublisher()
    }
}