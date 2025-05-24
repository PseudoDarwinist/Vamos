import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import CoreData

struct CardStatementUploadView: View {
    @State private var isShowingDocumentPicker = false
    @State private var pdfDocument: PDFDocument?
    @State private var documentName: String = ""
    @State private var documentURL: URL?
    @State private var extractedText: String = ""
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = StatementProcessorViewModel(context: PersistenceManager.shared.viewContext)
    
    enum ProcessingState {
        case idle
        case loading(progress: Double)
        case success
        case error(message: String)
    }
    
    @State private var processingState: ProcessingState = .idle
    @State private var creditCardStatement: CreditCardStatement?
    @State private var currentProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header with history button
                    HStack {
                        Text("Credit Card Statement")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        NavigationLink(destination: CardStatementHistoryView(viewModel: viewModel)) {
                            HStack {
                                Text("History")
                                    .font(.system(.subheadline, design: .rounded))
                                Image(systemName: "clock")
                            }
                            .foregroundColor(.primaryGreen)
                        }
                    }
                    
                    // Illustration - Hide during processing and after success to show progress view
                    if case .loading = processingState {
                        EmptyView()
                    } else if case .success = processingState {
                        EmptyView()
                    } else {
                        ZStack {
                            if let pdf = pdfDocument {
                                // PDF preview
                                VStack {
                                    // PDF name
                                    Text(documentName)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(1)
                                        .padding(.bottom, 4)
                                    
                                    // Use the existing PDFKitView from PDFDocumentView
                                    PDFKitView(pdf: pdf)
                                        .frame(height: 400)
                                        .cornerRadius(12)
                                }
                            } else {
                                // Placeholder
                                VStack {
                                    Image(systemName: "doc.text.viewfinder")
                                        .font(.system(size: 80))
                                        .foregroundColor(.primaryGreen.opacity(0.7))
                                        .padding()
                                    
                                    Text("Upload your credit card statement")
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.textPrimary)
                                    
                                    Text("We'll analyze your statement and categorize transactions automatically.")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                        .padding(.top, 8)
                                }
                                .frame(height: 300)
                                .frame(maxWidth: .infinity)
                                .background(Color.secondaryGreen.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Processing state
                    Group {
                        switch processingState {
                        case .idle:
                            EmptyView()
                        case .loading(let progress):
                            ProcessingProgressView(progress: $currentProgress)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentProgress = progress
                                    }
                                }
                                .onChange(of: progress) { newProgress in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentProgress = newProgress
                                    }
                                }
                                .padding()
                        case .success:
                            ProcessingProgressView(progress: .constant(1.0))
                                .padding()
                        case .error(let message):
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(message)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.red)
                            }
                            .padding()
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Process PDF button (visible only when PDF is loaded)
                        if let _ = pdfDocument, case .idle = processingState {
                            Button(action: {
                                processPDFDocument()
                            }) {
                                HStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                    Text("Analyze Statement")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primaryGreen)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .font(.system(.headline, design: .rounded))
                            }
                        }
                        
                        // Select PDF button
                        Button(action: {
                            isShowingDocumentPicker = true
                        }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text(pdfDocument == nil ? "Upload Statement" : "Select Different Statement")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pdfDocument == nil ? Color.primaryGreen : Color.secondaryGreen.opacity(0.2))
                            .foregroundColor(pdfDocument == nil ? .white : .primaryGreen)
                            .cornerRadius(12)
                        }
                        .disabled({
                            if case .loading = processingState {
                                return true
                            }
                            return false
                        }())
                        
                        if case .success = processingState {
                            NavigationLink(destination: CreditCardSummaryView(
                                statement: creditCardStatement, 
                                rawTransactionCount: 0
                            )) {
                                Text("View Results")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.secondaryBackground)
                                    .foregroundColor(.primaryGreen)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPickerViewRepresentable(onPickDocument: { url in
                loadPDF(from: url)
            })
        }
    }
    
    private func loadPDF(from url: URL) {
        print("💳 CardStatementUploadView: Loading PDF from URL: \(url)")
        guard url.startAccessingSecurityScopedResource() else {
            print("🔴 CardStatementUploadView: Failed to access security scoped resource")
            processingState = .error(message: "Failed to access the document. Please try again.")
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let pdfData = try Data(contentsOf: url)
            print("💳 CardStatementUploadView: PDF data loaded, size: \(pdfData.count / 1024) KB")
            
            if let document = PDFDocument(data: pdfData) {
                self.pdfDocument = document
                self.documentName = url.lastPathComponent
                self.documentURL = url
                self.processingState = .idle
                print("💳 CardStatementUploadView: PDF document created: \(url.lastPathComponent)")
            } else {
                print("🔴 CardStatementUploadView: Failed to create PDF document from data")
                processingState = .error(message: "Failed to load PDF. The file might be corrupted or not a valid PDF.")
            }
        } catch {
            print("🔴 CardStatementUploadView: Error loading PDF: \(error)")
            processingState = .error(message: "Error loading PDF: \(error.localizedDescription)")
        }
    }
    
    private func processPDFDocument() {
        guard pdfDocument != nil else {
            processingState = .error(message: "No document loaded")
            return
        }
        
        // Use our stored URL instead of document.documentURL
        guard let url = documentURL else {
            processingState = .error(message: "Unable to access document URL")
            return
        }
        
        // Create a bookmark to access the URL in the background
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            
            var isStale = false
            let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            // Make sure we can access the file
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                processingState = .error(message: "Could not access the document URL")
                return
            }
            
            // Start processing with the view model
            viewModel.processStatement(url: resolvedURL) { result in
                // Update UI based on processing result
                switch result {
                case .progress(let progress):
                    DispatchQueue.main.async {
                        self.processingState = .loading(progress: progress)
                    }
                case .success:
                    DispatchQueue.main.async {
                        resolvedURL.stopAccessingSecurityScopedResource()
                        self.creditCardStatement = self.viewModel.statement
                        self.processingState = .success
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        resolvedURL.stopAccessingSecurityScopedResource()
                        self.processingState = .error(message: error.localizedDescription)
                    }
                }
            }
        } catch {
            processingState = .error(message: "Error accessing document: \(error.localizedDescription)")
        }
    }
}

struct CardStatementUploadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CardStatementUploadView()
        }
    }
} 