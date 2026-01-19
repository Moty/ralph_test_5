export class ImageValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ImageValidationError';
  }
}

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/jpg', 'image/png'];
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB in bytes

export interface ImageValidationOptions {
  maxSizeInMB?: number;
  allowedFormats?: string[];
}

export function validateImageFormat(mimetype: string, options?: ImageValidationOptions): void {
  const allowedFormats = options?.allowedFormats || ALLOWED_MIME_TYPES;
  
  if (!allowedFormats.includes(mimetype)) {
    throw new ImageValidationError(
      'Invalid file format. Only JPG and PNG images are allowed'
    );
  }
}

export function validateImageSize(sizeInBytes: number, options?: ImageValidationOptions): void {
  const maxSize = options?.maxSizeInMB 
    ? options.maxSizeInMB * 1024 * 1024 
    : MAX_FILE_SIZE;
  
  if (sizeInBytes > maxSize) {
    const maxSizeInMB = maxSize / (1024 * 1024);
    throw new ImageValidationError(
      `File too large. Maximum size is ${maxSizeInMB}MB`
    );
  }
}

export function validateImage(
  mimetype: string, 
  sizeInBytes: number, 
  options?: ImageValidationOptions
): void {
  validateImageFormat(mimetype, options);
  validateImageSize(sizeInBytes, options);
}
