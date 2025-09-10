# ContractorLens Backend - Production Dockerfile
FROM node:18-alpine AS builder

# Install system dependencies for building native modules
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    postgresql-dev

WORKDIR /app

# Copy package files for dependency installation
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-alpine AS production

# Install runtime dependencies
RUN apk add --no-cache \
    postgresql-client \
    curl \
    && addgroup -g 1001 -S nodejs \
    && adduser -S contractorlens -u 1001

WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=contractorlens:nodejs . .

# Remove development files
RUN rm -rf tests/ *.md .env.example

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Run as non-root user
USER contractorlens

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "src/server.js"]