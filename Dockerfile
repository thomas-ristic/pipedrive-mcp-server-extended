# Multi-stage build for optimized image size
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY src ./src

# Build the application
RUN npm run build

# Production stage
FROM node:20-alpine

# Install wget for healthcheck and other utilities
RUN apk add --no-cache wget curl

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy built application from builder stage
COPY --from=builder /app/build ./build

# Copy entrypoint script
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

# Set NODE_ENV to production
ENV NODE_ENV=production

# Expose the default MCP port (SSE transport)
EXPOSE 3000

# Expose the default mcpo port (mcpo transport)
EXPOSE 8080

# Run as non-root user for security
USER node

# Use entrypoint script to handle different transports
ENTRYPOINT ["./entrypoint.sh"]
