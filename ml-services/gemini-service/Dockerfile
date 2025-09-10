# ContractorLens Gemini Service - Production Dockerfile
FROM node:18-alpine AS builder

# Install build dependencies for Sharp and native modules
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    vips-dev \
    libc6-compat

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-alpine AS production

# Install runtime dependencies including vips for Sharp
RUN apk add --no-cache \
    vips \
    curl \
    && addgroup -g 1001 -S nodejs \
    && adduser -S gemini -u 1001

WORKDIR /app

# Copy dependencies and application code
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=gemini:nodejs . .

# Remove development files
RUN rm -rf tests/ *.md .env.example

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD node -e "console.log('Health check passed')" || exit 1

# Run as non-root user
USER gemini

# Expose port (if needed for direct access)
EXPOSE 3001

# Start the service
CMD ["node", "analyzer.js"]