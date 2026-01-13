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

# Copy Prisma schema (optional - only needed for PostgreSQL)
COPY prisma ./prisma

# Generate Prisma Client (optional - only for PostgreSQL)
RUN npx prisma generate || echo "Prisma generation skipped - using Firestore"

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

# Conditional startup: run migrations only if using PostgreSQL
CMD if [ -n "$DATABASE_URL" ] && [ -z "$FIREBASE_PROJECT_ID" ]; then \
      npx prisma migrate deploy; \
    fi && npm start
