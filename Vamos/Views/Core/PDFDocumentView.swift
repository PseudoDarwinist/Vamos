import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFDocumentView: View {
    @State private var isShowingDocumentPicker = false
    @State private var pdfDocument: PDFDocument?
    @State private var documentName: String = ""
    
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
            
            Spacer()
        }
        .padding()
        .background(Color.background.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPickerViewRepresentable(onPickDocument: { url in
                loadPDF(from: url)
            })
        }
    }
    
    private func loadPDF(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let pdfData = try Data(contentsOf: url)
            if let document = PDFDocument(data: pdfData) {
                self.pdfDocument = document
                self.documentName = url.lastPathComponent
            }
        } catch {
            print("Error loading PDF: \(error)")
        }
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
