# Use official Node.js runtime as base image
FROM node:20-alpine

# Install dependencies for sharp (image processing)
RUN apk add --no-cache python3 make g++ vips-dev

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install ALL dependencies (including dev) for build
RUN npm ci

# Copy application source
COPY src ./src

# Build TypeScript to JavaScript
RUN npm run build

# Remove dev dependencies to reduce image size
RUN npm prune --production

# Expose port (Cloud Run will set PORT env var)
EXPOSE 8080

# Set production environment
ENV NODE_ENV=production

# Start the application
CMD ["npm", "start"]
