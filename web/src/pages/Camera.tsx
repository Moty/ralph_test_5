import { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '../components/ui';

export default function Camera() {
  const navigate = useNavigate();
  const [hasCamera, setHasCamera] = useState(false);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    startCamera();
    return () => {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
    };
  }, []);

  const startCamera = async () => {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' }
      });
      setStream(mediaStream);
      setHasCamera(true);
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
      }
    } catch (err) {
      setHasCamera(false);
    }
  };

  const capturePhoto = () => {
    if (!videoRef.current || !canvasRef.current) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.drawImage(video, 0, 0);
      const imageData = canvas.toDataURL('image/jpeg');
      setCapturedImage(imageData);
      
      canvas.toBlob((blob) => {
        if (blob) {
          const file = new File([blob], 'camera-capture.jpg', { type: 'image/jpeg' });
          setSelectedFile(file);
        }
      }, 'image/jpeg');
    }
    
    if (stream) {
      stream.getTracks().forEach(track => track.stop());
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      const reader = new FileReader();
      reader.onload = (event) => {
        setCapturedImage(event.target?.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const retake = () => {
    setCapturedImage(null);
    setSelectedFile(null);
    if (hasCamera) {
      startCamera();
    }
  };

  const continueToAnalyze = () => {
    if (selectedFile) {
      navigate('/camera/analyze', { state: { imageFile: selectedFile, imagePreview: capturedImage } });
    }
  };

  return (
    <div className="container">
      <h1>Capture Meal</h1>
      
      {capturedImage ? (
        <div>
          <img 
            src={capturedImage} 
            alt="Captured meal" 
            style={{ 
              width: '100%', 
              maxHeight: '60vh', 
              objectFit: 'contain',
              borderRadius: 'var(--border-radius-md)',
              marginBottom: 'var(--spacing-lg)'
            }} 
          />
          <div style={{ display: 'flex', gap: 'var(--spacing-md)' }}>
            <Button variant="secondary" fullWidth onClick={retake}>
              ↻ Retake
            </Button>
            <Button variant="primary" fullWidth onClick={continueToAnalyze}>
              Continue →
            </Button>
          </div>
        </div>
      ) : (
        <div>
          {hasCamera ? (
            <div>
              <video
                ref={videoRef}
                autoPlay
                playsInline
                style={{
                  width: '100%',
                  maxHeight: '60vh',
                  objectFit: 'cover',
                  borderRadius: 'var(--border-radius-md)',
                  marginBottom: 'var(--spacing-lg)',
                  backgroundColor: 'var(--color-surface-secondary)'
                }}
              />
              <canvas ref={canvasRef} style={{ display: 'none' }} />
              <Button variant="primary" fullWidth onClick={capturePhoto}>
                📸 Capture Photo
              </Button>
            </div>
          ) : (
            <div>
              <div 
                style={{
                  width: '100%',
                  height: '40vh',
                  backgroundColor: 'var(--color-surface-secondary)',
                  borderRadius: 'var(--border-radius-md)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: 'var(--spacing-lg)',
                  color: 'var(--color-text-secondary)'
                }}
              >
                <p>Camera not available</p>
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleFileSelect}
                style={{ display: 'none' }}
              />
              <Button 
                variant="primary" 
                fullWidth 
                onClick={() => fileInputRef.current?.click()}
              >
                📁 Upload Photo
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
