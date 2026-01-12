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
    
    private let apiService = APIService()
    
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
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    
                    HStack(spacing: 40) {
                        Button("Retake") {
                            capturedImage = nil
                            camera.retake()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Button("Confirm") {
                            analyzeImage(image)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                }
            } else {
                // Camera preview
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    Button(action: {
                        camera.capturePhoto { image in
                            if let compressed = compressImage(image) {
                                capturedImage = compressed
                            }
                        }
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                            )
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            camera.requestPermission()
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
            return "Invalid server URL configuration."
        case .invalidResponse:
            return "Received invalid response from server."
        case .networkError:
            return "Network error. Please check your connection."
        case .decodingError:
            return "Failed to parse server response."
        case .serverError(let message):
            return message
        case .timeout:
            return "Request timed out. Please try again."
        case .noImageData:
            return "Failed to process image data."
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
    
    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupCamera()
                }
            }
        case .authorized:
            setupCamera()
        default:
            break
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
