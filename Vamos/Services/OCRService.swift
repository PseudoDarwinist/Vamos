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
        print("🟢 Starting extractStructuredData")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("🔴 Error: Failed to convert image to JPEG data")
            return Fail(error: NSError(domain: "OCRService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"]))
                .eraseToAnyPublisher()
        }
        
        // Log image details
        print("🟢 Image size: \(image.size.width) x \(image.size.height)")
        print("🟢 Image data size: \(Double(imageData.count) / 1024.0) KB")
        
        // If image is too large, resize it
        let maxSizeKB: Double = 1024 // 1MB
        if Double(imageData.count) / 1024.0 > maxSizeKB {
            print("🟠 Warning: Image is large (\(Double(imageData.count) / 1024.0) KB), attempting to resize")
            
            // Resize image to reduce data size
            let compressionRatio = maxSizeKB / (Double(imageData.count) / 1024.0)
            if let resizedImageData = image.jpegData(compressionQuality: CGFloat(compressionRatio * 0.8)) {
                print("🟢 Resized image data size: \(Double(resizedImageData.count) / 1024.0) KB")
                return geminiService.extractReceiptInfo(imageData: resizedImageData)
            }
        }
        
        return geminiService.extractReceiptInfo(imageData: imageData)
    }
    
    // Process receipt and return Transaction object
        func processReceipt(image: UIImage) -> AnyPublisher<Transaction, Error> {
        return extractStructuredData(from: image)
            .map { data -> Transaction in
                // Debug logging for the extracted data
                print("📊 RECEIPT DATA EXTRACTED:")
                print("  - Raw data: \(data)")
                print("  - Merchant: \(data["merchant_name"] as? String ?? "nil")")
                print("  - Amount: \(data["total_amount"] as? String ?? "nil")")
                print("  - Date: \(data["date"] as? String ?? "nil")")
                print("  - Category: \(data["category"] as? String ?? "nil")")
                
                // Parse extracted data
                let amount: Decimal
                if let amountString = data["total_amount"] as? String {
                    amount = Decimal(string: amountString) ?? 0.0
                } else if let amountNumber = data["total_amount"] as? NSNumber {
                    amount = Decimal(amountNumber.doubleValue)
                } else {
                    amount = 0.0
                }
                
                let dateString = data["date"] as? String ?? ""
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let date = dateFormatter.date(from: dateString) ?? Date()
                
                let merchant = data["merchant_name"] as? String ?? "Unknown Merchant"
                let categoryName = data["category"] as? String ?? "Miscellaneous"
                
                print("📊 CREATING TRANSACTION:")
                print("  - Merchant: \(merchant)")
                print("  - Category: \(categoryName)")
                
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