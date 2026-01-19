import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit

struct CameraView: View {
    @StateObject private var camera = CameraController()
    @State private var capturedImage: UIImage?
    @State private var showResults = false
    @State private var isAnalyzing = false
    @State private var analysisResult: MealAnalysis?
    @State private var analysisError: String?
    @State private var showPermissionAlert = false
    
    let apiService: APIService
    private let storageService = StorageService.shared
    
    var body: some View {
        ZStack {
            if showResults {
                // Show nutrition results
                NutritionResultView(
                    analysis: analysisResult,
                    error: analysisError,
                    isLoading: isAnalyzing,
                    onDismiss: {
                        showResults = false
                        capturedImage = nil
                        analysisResult = nil
                        analysisError = nil
                        camera.retake()
                    }
                )
            } else if let image = capturedImage {
                // Preview captured photo
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding()
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Spacer()
                        
                        HStack(spacing: 50) {
                            Button(action: {
                                capturedImage = nil
                                camera.retake()
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Retake")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: {
                                analyzeImage(image)
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(AppGradients.primary)
                                            .frame(width: 70, height: 70)
                                            .shadow(color: AppColors.primaryGradientStart.opacity(0.5), radius: 10, x: 0, y: 4)
                                        
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Analyze")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.bottom, 50)
                    }
                }
            } else {
                // Camera preview
                if camera.permissionDenied {
                    ZStack {
                        AppGradients.background
                            .ignoresSafeArea()
                        
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            }
                            
                            Text("Camera Access Required")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Please enable camera access in Settings to use this feature.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open Settings")
                                }
                                .fontWeight(.semibold)
                            }
                            .buttonStyle(GradientButtonStyle())
                        }
                        .padding(40)
                        .glassMorphism()
                        .padding()
                    }
                } else {
                    ZStack {
                        CameraPreview(session: camera.session)
                            .ignoresSafeArea()
                        
                        // Viewfinder overlay
                        VStack {
                            Spacer()
                            
                            // Capture hints
                            Text("Position your meal in the frame")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Capsule())
                                .padding(.bottom, 20)
                            
                            // Capture button
                            Button(action: {
                                camera.capturePhoto { image in
                                    if let compressed = compressImage(image) {
                                        capturedImage = compressed
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(AppGradients.primary)
                                        .frame(width: 75, height: 75)
                                        .shadow(color: AppColors.primaryGradientStart.opacity(0.5), radius: 10, x: 0, y: 4)
                                    
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 85, height: 85)
                                    
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.bottom, 50)
                        }
                    }
                }
            }
        }
        .onAppear {
            camera.requestPermission { granted in
                if !granted {
                    showPermissionAlert = true
                }
            }
        }
        .onDisappear {
            // Reset camera state when navigating away
            if !showResults {
                capturedImage = nil
            }
        }
        .alert("Camera Permission Denied", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Camera access is required to take photos of your food. Please enable camera access in Settings.")
        }
    }
    
    private func compressImage(_ image: UIImage) -> UIImage? {
        let maxSize: CGFloat = 2_000_000 // 2MB in bytes
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > Int(maxSize) && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
    
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        showResults = true
        analysisError = nil
        analysisResult = nil
        
        Task {
            do {
                let result = try await apiService.analyzeImage(image)
                
                // Save to local storage
                let thumbnailData = image.jpegData(compressionQuality: 0.5)
                try? await MainActor.run {
                    try storageService.save(analysis: result, thumbnail: thumbnailData)
                }
                
                await MainActor.run {
                    isAnalyzing = false
                    analysisResult = result
                }
            } catch let error as APIError {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = errorMessage(for: error)
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = "An unexpected error occurred. Please try again."
                }
            }
        }
    }
    
    private func errorMessage(for error: APIError) -> String {
        switch error {
        case .invalidURL:
            return "Configuration error. Please check settings."
        case .invalidResponse:
            return "Unable to process server response."
        case .networkError:
            return "Network error occurred. Please try again."
        case .decodingError:
            return "Unable to read analysis results."
        case .serverError(let message):
            // Don't expose internal error details
            if message.lowercased().contains("gemini") || message.lowercased().contains("api") {
                return "Analysis service temporarily unavailable."
            }
            return "Unable to analyze image. Please try again."
        case .timeout:
            return "Request timed out. Please try again."
        case .noImageData:
            return "Image processing failed. Please try again."
        case .noInternetConnection:
            return "No internet connection. Please check your network."
        case .unauthorized:
            return "Please log in to analyze images."
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                layer.frame = uiView.bounds
            }
        }
    }
}

class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var photoCompletion: ((UIImage) -> Void)?
    @Published var permissionDenied = false
    
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera()
                        completion?(true)
                    } else {
                        self.permissionDenied = true
                        completion?(false)
                    }
                }
            }
        case .authorized:
            setupCamera()
            completion?(true)
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
                completion?(false)
            }
        @unknown default:
            DispatchQueue.main.async {
                self.permissionDenied = true
                completion?(false)
            }
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func retake() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        DispatchQueue.main.async {
            self.photoCompletion?(image)
            self.session.stopRunning()
        }
    }
}

#else

// Fallback for non-iOS platforms
struct CameraView: View {
    var body: some View {
        Text("Camera is only available on iOS")
            .padding()
    }
}

#endif
