
# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install dependencies required for CGO
RUN apk add --no-cache git make build-base

# Copy go mod files
COPY backend/go.mod backend/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY backend/ .

# Build the application with CGO enabled
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o analyzer ./cmd/main.go


# Runtime stage - Alpine for minimal image size (suitable for Raspberry Pi)
FROM alpine:latest

# Install CA certificates for HTTPS and wget for healthcheck
RUN apk --no-cache add ca-certificates libc6-compat wget

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/analyzer .

# Create necessary directories
RUN mkdir -p /app/certs /app/data /app/logs

# Set proper permissions
RUN chmod 700 /app/certs /app/data /app/logs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider https://localhost/healthz || exit 1

# Expose HTTPS port
EXPOSE 443

# Run as non-root user
RUN addgroup -g 1000 analyzer && \
    adduser -D -u 1000 -G analyzer analyzer

USER analyzer

# Start the application
CMD ["./analyzer"]