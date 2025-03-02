import SwiftUI
import AVFoundation
import PhotosUI
import Combine

struct ScannerView: View {
    @State private var activeTab: ScannerTab = .camera
    @State private var capturedImage: UIImage?
    @State private var isShowingCapturedImage = false
    @State private var isShowingPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var transactionResult: Transaction?
    @Environment(\.presentationMode) var presentationMode
    @State private var cancellables = Set<AnyCancellable>()
    // Add OCR service for processing
    private let ocrService = OCRService()
    
    // UIViewController to use for presenting sheets
    @State private var hostingController: UIViewController?
    
    enum ScannerTab {
        case camera
        case document
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .padding(8)
                        .background(Color.secondaryGreen.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Scan Receipt")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                // Empty view for balance
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Tab selector
            HStack {
                tabButton(title: "Camera", systemImage: "camera.fill", tab: .camera)
                tabButton(title: "Document", systemImage: "doc.text.fill", tab: .document)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Content based on selected tab
            if activeTab == .camera {
                if isShowingCapturedImage, let image = capturedImage {
                    // Show captured image
                    VStack {
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
                                // Process the image
                                processReceipt()
                            }) {
                                Text("Use Photo")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.primaryGreen)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.bottom)
                    }
                } else {
                    // Camera view with photo library option for simulator
                    VStack {
                        CameraView(capturedImage: $capturedImage, isShowingCapturedImage: $isShowingCapturedImage)
                        
                        // Photo library button for simulator testing
                        Button(action: {
                            isShowingPhotosPicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 16))
                                Text("Select from Photo Library")
                                    .font(.system(.subheadline, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.secondaryGreen)
                            .cornerRadius(12)
                        }
                        .padding()
                    }
                }
            } else {
                // Document scanner
                PDFDocumentView()
            }
            
            // Processing indicator
            if isProcessing {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryGreen))
                    
                    Text("Processing receipt...")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primaryGreen)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
                .edgesIgnoringSafeArea(.all)
            }
        }
        .background(Color.background.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $isShowingPhotosPicker) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Select a receipt image")
                    .font(.system(.headline, design: .rounded))
            }
            .onChange(of: selectedPhotoItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                capturedImage = image
                                isShowingCapturedImage = true
                                isShowingPhotosPicker = false
                            }
                        }
                    }
                }
            }
        }
        .background(ViewControllerRepresentable { viewController in
            // Store the view controller for later use
            self.hostingController = viewController
        })
    }
    
    // In ScannerView.swift

// In ScannerView.swift, update processReceipt method
private func processReceipt() {
    guard let image = capturedImage else { return }
    
    isProcessing = true
    
    // Process receipt using OCR service
    ocrService.processReceipt(image: image)
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { completion in
            isProcessing = false
            switch completion {
            case .finished:
                print("✅ Data extraction completed")
                // Just dismiss this view - the transaction is already added to the store
                self.presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                print("❌ Receipt processing failed: \(error.localizedDescription)")
            }
        }, receiveValue: { transaction in
            // Add transaction to store and print debug info
            print("📊 RECEIVED TRANSACTION: \(transaction.merchant) - \(transaction.amount)")
            TransactionStore.shared.addTransaction(transaction)
        })
        .store(in: &cancellables)
}

// New helper method to show the transaction edit screen
private func showTransactionEdit(for image: UIImage) {
    // Extract the basic data needed for the edit view
    let merchantName = "KFC"  // Default or extract from image
    let amount = Decimal(1187.00)  // Default or extract from image
    let category = Category.sample(name: "Food & Dining")
    
    // Create and present the edit view directly in SwiftUI
    let editView = TransactionEditView(
        merchantName: merchantName,
        amount: amount,
        date: Date(),
        category: category
    )
    
    // Create a hosting controller and present it
    let hostingController = UIHostingController(rootView: editView)
    UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
    
    // Dismiss the scanner view
    self.presentationMode.wrappedValue.dismiss()
}
    
    private func tabButton(title: String, systemImage: String, tab: ScannerTab) -> some View {
        let isSelected = activeTab == tab
        
        return Button(action: {
            withAnimation {
                activeTab = tab
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundColor(isSelected ? .primaryGreen : .textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondaryGreen.opacity(0.2))
                    }
                }
            )
        }
    }
}

// Helper to get access to the underlying UIViewController
struct ViewControllerRepresentable: UIViewControllerRepresentable {
    let onAppear: (UIViewController) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        onAppear(uiViewController)
    }
}

// Camera view using AVFoundation
struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isShowingCapturedImage: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let cameraController = CameraViewController()
        cameraController.delegate = context.coordinator
        
        controller.addChild(cameraController)
        controller.view.addSubview(cameraController.view)
        cameraController.view.frame = controller.view.bounds
        cameraController.didMove(toParent: controller)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func didCapture(image: UIImage) {
            parent.capturedImage = image
            parent.isShowingCapturedImage = true
        }
    }
}

// Protocol for camera delegate
protocol CameraViewControllerDelegate: AnyObject {
    func didCapture(image: UIImage)
}

// Camera view controller using AVFoundation
class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let photoOutput = AVCapturePhotoOutput()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .photo
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            print("Unable to access camera")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        if let previewLayer = previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }
        
        let captureButton = UIButton(type: .system)
        captureButton.setImage(UIImage(systemName: "circle.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        captureButton.tintColor = .white
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        view.addSubview(captureButton)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        delegate?.didCapture(image: image)
    }
}