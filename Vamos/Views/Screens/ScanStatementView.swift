// File: Vamos/Views/Screens/ScanStatementView.swift

import SwiftUI
import Combine
import PhotosUI

struct ScanStatementView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var cardStore = CardStore.shared
    
    // Optional preselected card
    var preselectedCard: Card?
    
    // State
    @State private var capturedImage: UIImage?
    @State private var isShowingCapturedImage = false
    @State private var isProcessing = false
    @State private var extractedData: OCRService.StatementData?
    @State private var showVerification = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isShowingPhotosPicker = false
    @State private var showingCamera = false
    @State private var errorMessage: String?
    
    // OCR service
    private let ocrService = OCRService()
    
    init(preselectedCard: Card? = nil) {
        self.preselectedCard = preselectedCard
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.background
                    .edgesIgnoringSafeArea(.all)
                
                // Content
                VStack(spacing: 16) {
                    // Instruction text
                    Text("Scan your credit card statement to extract cashback details automatically")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Camera or captured image view
                    if isShowingCapturedImage, let image = capturedImage {
                        // Show captured image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .padding()
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                isShowingCapturedImage = false
                                capturedImage = nil
                            }) {
                                Text("Retake")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                processStatement()
                            }) {
                                Text("Use Photo")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.primaryGreen)
                                    .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                        }
                        .padding(.bottom)
                    } else {
                        // Empty state with camera and photo library options
                        ZStack {
                            Color.black.opacity(0.1)
                                .frame(height: 300)
                                .cornerRadius(16)
                            
                            VStack(spacing: 20) {
                                Image(systemName: "doc.viewfinder")
                                    .font(.system(size: 60))
                                    .foregroundColor(.primaryGreen.opacity(0.6))
                                
                                Text("Upload your statement")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                HStack(spacing: 20) {
                                    // Camera button
                                    Button(action: {
                                        showingCamera = true
                                    }) {
                                        VStack {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                                .padding(12)
                                                .background(Color.primaryGreen)
                                                .clipShape(Circle())
                                            
                                            Text("Camera")
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundColor(.textPrimary)
                                        }
                                    }
                                    
                                    // Photo library button
                                    Button(action: {
                                        isShowingPhotosPicker = true
                                    }) {
                                        VStack {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                                .padding(12)
                                                .background(Color.secondaryGreen)
                                                .clipShape(Circle())
                                            
                                            Text("Gallery")
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundColor(.textPrimary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // OR divider
                        HStack {
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.2))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 8)
                            
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        
                        // Manual entry form
                        VStack(spacing: 16) {
                            // Card selection (if no preselected card)
                            if preselectedCard == nil {
                                manualCardSelection
                            }
                            
                            // Statement period and amount would go here
                            Text("Or switch to manual entry for more control")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                                // In a real app, you'd use a coordinator to show ManualEntryView
                            }) {
                                Text("Switch to Manual Entry")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.primaryGreen)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primaryGreen, lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                // Processing overlay
                if isProcessing {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Processing statement...")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                // Error message if any
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        
                        Text(error)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding()
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitle("Scan Statement", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $isShowingPhotosPicker) {
                PhotoPicker(image: $capturedImage, isShown: $isShowingPhotosPicker, isShowingCapturedImage: $isShowingCapturedImage)
            }
            .sheet(isPresented: $showingCamera) {
                Camera(capturedImage: $capturedImage, isShown: $showingCamera, isShowingCapturedImage: $isShowingCapturedImage)
            }
            .sheet(isPresented: $showVerification) {
                if let image = capturedImage, let data = extractedData {
                    VerifyStatementView(
                        extractedData: data,
                        statementImage: image,
                        preselectedCard: preselectedCard
                    )
                }
            }
        }
    }
    
    // Card selection for manual entry
    private var manualCardSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select your card")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.textSecondary)
            
            if cardStore.cards.isEmpty {
                HStack {
                    Text("No cards added yet")
                        .foregroundColor(.gray)
                    Spacer()
                    Button("Add Card") {
                        // Would use a coordinator here
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primaryGreen)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            } else {
                // Simple placeholder for card selection
                HStack {
                    if let card = cardStore.cards.first {
                        ZStack {
                            Rectangle()
                                .fill(card.color)
                                .frame(width: 35, height: 25)
                                .cornerRadius(3)
                            
                            Text(card.issuer)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        Text("\(card.nickname) (••••\(card.lastFourDigits))")
                            .foregroundColor(.textPrimary)
                    } else {
                        Text("Select a card")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // Process the statement using OCR and Gemini
    private func processStatement() {
        guard let image = capturedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        // First try using Gemini to extract data
        let geminiService = GeminiService()
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            isProcessing = false
            errorMessage = "Failed to process image"
            return
        }
        
        geminiService.extractReceiptInfo(imageData: imageData)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        // Successfully processed with Gemini
                        break
                    case .failure(let error):
                        print("Error processing with Gemini: \(error.localizedDescription)")
                        // Fall back to OCR processing
                        fallbackToOCR(image: image)
                    }
                },
                receiveValue: { data in
                    isProcessing = false
                    
                    // Create statement data from Gemini response
                    var statementData = OCRService.StatementData()
                    
                    // Extract card number if present
                    if let cardNumber = data["merchant_name"] as? String {
                        if cardNumber.contains("••••") {
                            let components = cardNumber.components(separatedBy: "••••")
                            if components.count > 1 {
                                statementData.cardNumber = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } else if let lastFour = data["last_four"] as? String {
                            statementData.cardNumber = lastFour
                        }
                    }
                    
                    // Extract date if present
                    if let dateString = data["date"] as? String {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        
                        if let date = dateFormatter.date(from: dateString) {
                            // Set both start and end date to the same date initially
                            statementData.periodStart = date
                            
                            // Create end date as last day of the month
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.year, .month], from: date)
                            if let startOfMonth = calendar.date(from: components),
                               let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) {
                                statementData.periodEnd = endOfMonth
                            } else {
                                statementData.periodEnd = date
                            }
                        }
                    }
                    
                    // Extract amount if present
                    if let amountString = data["total_amount"] as? String {
                        statementData.cashbackAmount = Decimal(string: amountString.replacingOccurrences(of: ",", with: ""))
                    } else if let amount = data["total_amount"] as? NSNumber {
                        statementData.cashbackAmount = Decimal(amount.doubleValue)
                    }
                    
                    // Extract bank name if present
                    if let merchantName = data["merchant_name"] as? String {
                        let bankNames = ["HDFC", "ICICI", "SBI", "Axis", "Kotak", "HSBC", "Citi", "Standard Chartered"]
                        for bank in bankNames {
                            if merchantName.contains(bank) {
                                statementData.bankName = bank
                                break
                            }
                        }
                    }
                    
                    self.extractedData = statementData
                    self.showVerification = true
                }
            )
            .store(in: &cancellables)
    }
    
    // Fallback to OCR if Gemini fails
    private func fallbackToOCR(image: UIImage) {
        ocrService.processStatement(image: image)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isProcessing = false
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("Error processing statement with OCR: \(error.localizedDescription)")
                        errorMessage = "Failed to extract statement data. Please try again or use manual entry."
                    }
                },
                receiveValue: { statementData in
                    self.extractedData = statementData
                    self.showVerification = true
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Photo Picker using PhotosUI
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isShown: Bool
    @Binding var isShowingCapturedImage: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isShown = false
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        if let uiImage = image as? UIImage {
                            self.parent.image = uiImage
                            self.parent.isShowingCapturedImage = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera using UIImagePickerController
struct Camera: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isShown: Bool
    @Binding var isShowingCapturedImage: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: Camera
        
        init(_ parent: Camera) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                parent.capturedImage = image
                parent.isShowingCapturedImage = true
            }
            
            parent.isShown = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isShown = false
        }
    }
}