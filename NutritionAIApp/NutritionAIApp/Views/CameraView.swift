//
//  CameraView.swift
//  NutritionAIApp
//

import SwiftUI
import AVFoundation
import Combine

struct CameraView: View {
    @StateObject private var camera = CameraManager()
    @State private var showPreview = false
    @State private var showResults = false
    
    var body: some View {
        ZStack {
            if camera.permissionGranted {
                if showPreview, let image = camera.capturedImage {
                    // Photo preview
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            HStack(spacing: 40) {
                                Button(action: {
                                    showPreview = false
                                    camera.capturedImage = nil
                                }) {
                                    VStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.title)
                                        Text("Retake")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showResults = true
                                }) {
                                    VStack {
                                        Image(systemName: "checkmark")
                                            .font(.title)
                                        Text("Confirm")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                } else {
                    // Camera preview
                    ZStack {
                        CameraPreviewView(session: camera.session)
                            .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            Button(action: {
                                camera.capturePhoto()
                                showPreview = true
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
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Please enable camera access in Settings to use this feature")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }
            }
        }
        .onAppear {
            camera.checkPermission()
        }
        .onDisappear {
            showPreview = false
            camera.capturedImage = nil
        }
        .fullScreenCover(isPresented: $showResults) {
            if let image = camera.capturedImage {
                NutritionResultView(image: image)
                    .onDisappear {
                        showPreview = false
                        camera.capturedImage = nil
                    }
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
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
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var permissionGranted = false
    @Published var capturedImage: UIImage?
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.permissionGranted = granted
                if granted {
                    self?.setupCamera()
                }
            }
        }
    }
    
    func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        
        Task {
            session.startRunning()
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        // Compress image to under 2MB
        let compressedImage = compressImage(image, targetSizeInMB: 2.0)
        
        Task { @MainActor in
            self.capturedImage = compressedImage
        }
    }
    
    nonisolated private func compressImage(_ image: UIImage, targetSizeInMB: Double) -> UIImage {
        let targetSizeInBytes = targetSizeInMB * 1024 * 1024
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, Double(data.count) > targetSizeInBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        if let data = imageData, let compressedImage = UIImage(data: data) {
            return compressedImage
        }
        
        return image
    }
}

#Preview {
    CameraView()
}
