# Multi-stage build for Go Billing Exporter
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY backend/go_exporter/go.mod backend/go_exporter/go.sum ./
RUN go mod download

# Copy source code
COPY backend/go_exporter/*.go ./

# Build binary with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -X main.version=$(git describe --tags)" \
    -o rct_exporter .

# Final stage
FROM alpine:3.24

RUN apk add --no-cache ca-certificates

COPY --from=builder /app/rct_exporter /usr/local/bin/rct_exporter

EXPOSE 9102

USER 65534:65534

ENTRYPOINT ["/usr/local/bin/rct_exporter"]
