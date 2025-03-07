import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Combine

struct PDFDocumentView: View {
    @State private var isShowingDocumentPicker = false
    @State private var pdfDocument: PDFDocument?
    @State private var documentName: String = ""
    @State private var isProcessing = false
    @State private var processingError: String?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showTransactionEdit = false
    @State private var transactionResult: Transaction?
    @Environment(\.presentationMode) var presentationMode
    
    // Transaction store for adding processed transactions
    @ObservedObject private var transactionStore = TransactionStore.shared
    
    // Replace LandingAI with Gemini service
    private let geminiService = GeminiService()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("PDF Document Scanner")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primaryGreen)
                .padding(.top)
            
            // PDF preview
            ZStack {
                if let pdf = pdfDocument {
                    VStack {
                        // PDF name
                        Text(documentName)
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                            .padding(.bottom, 4)
                        
                        // PDF preview
                        PDFKitView(pdf: pdf)
                            .frame(height: 400)
                            .cornerRadius(12)
                    }
                } else {
                    // Placeholder
                    VStack {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.primaryGreen.opacity(0.6))
                        
                        Text("No PDF Selected")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .padding(.top)
                    }
                    .frame(height: 400)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondaryGreen.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Process PDF button (visible only when PDF is loaded)
            if pdfDocument != nil {
                Button(action: {
                    processPDFDocument()
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Process PDF")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.system(.headline, design: .rounded))
                }
                .disabled(isProcessing)
            }
            
            // Select PDF button
            Button(action: {
                isShowingDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Select PDF")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondaryGreen.opacity(0.2))
                .foregroundColor(.primaryGreen)
                .cornerRadius(12)
                .font(.system(.headline, design: .rounded))
            }
            .disabled(isProcessing)
            
            // Error message
            if let error = processingError {
                Text(error)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .background(Color.background.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPickerViewRepresentable(onPickDocument: { url in
                loadPDF(from: url)
            })
        }
        .sheet(isPresented: $showTransactionEdit) {
            if let transaction = transactionResult {
                TransactionEditView(transaction: transaction)
            }
        }
        .overlay(
            Group {
                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .primaryGreen))
                        
                        Text("Processing document...")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.primaryGreen)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .edgesIgnoringSafeArea(.all)
                }
            }
        )
    }
    
    private func loadPDF(from url: URL) {
        print("📄 PDFDocumentView: Loading PDF from URL: \(url)")
        guard url.startAccessingSecurityScopedResource() else {
            print("🔴 PDFDocumentView: Failed to access security scoped resource")
            processingError = "Failed to access the document. Please try again."
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let pdfData = try Data(contentsOf: url)
            print("📄 PDFDocumentView: PDF data loaded, size: \(pdfData.count / 1024) KB")
            
            if let document = PDFDocument(data: pdfData) {
                self.pdfDocument = document
                self.documentName = url.lastPathComponent
                print("📄 PDFDocumentView: PDF document created: \(url.lastPathComponent)")
                self.processingError = nil
            } else {
                print("🔴 PDFDocumentView: Failed to create PDF document from data")
                processingError = "Failed to load PDF. The file might be corrupted or not a valid PDF."
            }
        } catch {
            print("🔴 PDFDocumentView: Error loading PDF: \(error)")
            processingError = "Error loading PDF: \(error.localizedDescription)"
        }
    }
    
    private func processPDFDocument() {
        guard let document = pdfDocument, let pdfData = document.dataRepresentation() else {
            print("🔴 PDFDocumentView: No PDF document to process")
            processingError = "No PDF document selected. Please select a PDF first."
            return
        }
        
        print("📄 PDFDocumentView: Starting to process PDF with Gemini API: \(documentName)")
        isProcessing = true
        processingError = nil
        
        geminiService.processPDFDocument(pdfData: pdfData)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isProcessing = false
                    
                    switch completion {
                    case .finished:
                        print("✅ PDFDocumentView: PDF processing completed successfully")
                        // Success will be handled in receiveValue
                        // Dismiss this view and navigate to home
                        NotificationCenter.default.post(name: NSNotification.Name("NavigateToHomeView"), object: nil)
                        self.presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        print("🔴 PDFDocumentView: PDF processing failed: \(error.localizedDescription)")
                        processingError = "Failed to process document: \(error.localizedDescription)"
                    }
                },
                receiveValue: { transaction in
                    print("📄 PDFDocumentView: Received transaction data: \(transaction.merchant), \(transaction.amount)")
                    
                    // Store the transaction directly without showing edit view
                    TransactionStore.shared.addTransaction(transaction)
                }
            )
            .store(in: &cancellables)
    }
}

// PDF view using PDFKit
struct PDFKitView: UIViewRepresentable {
    let pdf: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdf
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = pdf
    }
}

// Document Picker
struct DocumentPickerViewRepresentable: UIViewControllerRepresentable {
    var onPickDocument: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerViewRepresentable
        
        init(_ parent: DocumentPickerViewRepresentable) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPickDocument(url)
        }
    }
}