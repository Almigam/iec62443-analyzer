.PHONY: help build build-pi run dev docker-build docker-run clean test hardening tls setup-pi

# Variables
BINARY_NAME=analyzer
GOOS?=linux
GOARCH?=amd64
GO_VERSION=1.22

help:
	@echo "IEC 62443-3-3 Analyzer - Makefile Commands"
	@echo ""
	@echo "Development:"
	@echo "  make dev              - Run backend in development mode"
	@echo "  make build            - Build binary for current OS"
	@echo "  make build-pi         - Build binary for Raspberry Pi (ARM64)"
	@echo "  make test             - Run tests"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build     - Build Docker image"
	@echo "  make docker-run       - Run with Docker Compose"
	@echo "  make docker-stop      - Stop Docker containers"
	@echo ""
	@echo "Raspberry Pi Deployment:"
	@echo "  make hardening        - Run OS hardening script"
	@echo "  make tls              - Generate TLS certificates"
	@echo "  make setup-pi         - Complete Pi setup"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean            - Clean build artifacts"
	@echo "  make logs             - View analyzer logs"
	@echo ""

# Development
dev:
	@echo "Starting development server..."
	cd backend && go run ./cmd/main.go

build:
	@echo "Building for $(GOOS)/$(GOARCH)..."
	cd backend && CGO_ENABLED=1 go build -o $(BINARY_NAME) ./cmd/main.go
	@echo "Binary: backend/$(BINARY_NAME)"

build-pi:
	@echo "Building for Raspberry Pi (ARM64)..."
	cd backend && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o $(BINARY_NAME) ./cmd/main.go
	@echo "Binary: backend/$(BINARY_NAME)"
	@echo "Copy to Pi: scp -i ~/.ssh/pi_key backend/$(BINARY_NAME) pi@192.168.1.x:~/"

test:
	@echo "Running tests..."
	cd backend && go test ./... -v

# Docker
docker-build:
	@echo "Building Docker image..."
	docker build -t iec62443-analyzer:latest .

docker-run: docker-build
	@echo "Starting with Docker Compose..."
	docker-compose up -d
	@echo "Logs: docker logs -f iec62443-analyzer"

docker-stop:
	@echo "Stopping Docker containers..."
	docker-compose down

# Raspberry Pi Setup
hardening:
	@echo "Running OS hardening script (requires sudo)..."
	@if [ -f raspberry-pi-config/os-hardening.sh ]; then \
		sudo bash raspberry-pi-config/os-hardening.sh; \
	else \
		echo "Error: os-hardening.sh not found"; \
		exit 1; \
	fi

tls:
	@echo "Generating TLS certificates..."
	bash raspberry-pi-config/tls-setup.sh

setup-pi: hardening tls
	@echo ""
	@echo "Raspberry Pi OS hardening complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Make a standalone build: make build-pi"
	@echo "2. Copy binary to Pi"
	@echo "3. Deploy analyzer"
	@echo ""

# Deployment to Pi (from local machine)
deploy-pi: build-pi
	@echo "Deploying to Raspberry Pi..."
	@read -p "Enter Pi hostname/IP (default: pi@192.168.1.x): " PI_HOST; \
	PI_HOST=$${PI_HOST:-pi@192.168.1.x}; \
	scp -i ~/.ssh/pi_key backend/$(BINARY_NAME) $$PI_HOST:~/; \
	ssh -i ~/.ssh/pi_key $$PI_HOST "sudo systemctl stop iec62443-analyzer 2>/dev/null || true"; \
	ssh -i ~/.ssh/pi_key $$PI_HOST "sudo cp ~/$(BINARY_NAME) /opt/analyzer/$(BINARY_NAME)"; \
	ssh -i ~/.ssh/pi_key $$PI_HOST "sudo systemctl start iec62443-analyzer"; \
	echo "Deployment complete!"

# Logs and Monitoring
logs:
	@if [ -f /etc/systemd/system/iec62443-analyzer.service ]; then \
		sudo journalctl -u iec62443-analyzer -f; \
	else \
		echo "Service not found. Are you on Raspberry Pi?"; \
	fi

status:
	@echo "=== Analyzer Status ==="
	@if [ -f /etc/systemd/system/iec62443-analyzer.service ]; then \
		sudo systemctl status iec62443-analyzer; \
	else \
		echo "Service not installed"; \
	fi
	@echo ""
	@echo "=== Firewall Status ==="
	@sudo ufw status 2>/dev/null || echo "UFW not installed"
	@echo ""
	@echo "=== Resource Usage ==="
	@top -b -n 1 -p $$(pgrep -f analyzer) 2>/dev/null | tail -2 || echo "Analyzer not running"

restart:
	@if [ -f /etc/systemd/system/iec62443-analyzer.service ]; then \
		sudo systemctl restart iec62443-analyzer; \
		echo "Service restarted"; \
	else \
		echo "Service not installed"; \
	fi

# Utilities
clean:
	@echo "Cleaning build artifacts..."
	rm -f backend/$(BINARY_NAME)
	rm -rf backend/.build
	@echo "Done!"

install-deps:
	@echo "Installing dependencies..."
	cd backend && go mod download
	cd frontend && npm install
	@echo "Done!"

lint:
	@echo "Running linters..."
	cd backend && go vet ./...
	cd frontend && npm run lint

format:
	@echo "Formatting code..."
	cd backend && go fmt ./...

deps-update:
	@echo "Updating dependencies..."
	cd backend && go get -u ./...
	cd frontend && npm update

# Security
security-check:
	@echo "Running security checks..."
	@echo "Backend:"
	cd backend && go vet ./... && gosec ./... || true
	@echo "Frontend:"
	cd frontend && npm audit || true

# Documentation
docs:
	@echo "Opening documentation..."
	@which xdg-open > /dev/null && xdg-open SETUP.md || open SETUP.md

# Initialize new Raspberry Pi
init-pi:
	@echo "Initializing Raspberry Pi..."
	@echo "1. Run this on Pi: sudo bash os-hardening.sh"
	@echo "2. Then: bash tls-setup.sh"
	@echo "3. Copy binaries and systemd service"
	@echo "4. systemctl start iec62443-analyzer"
	@echo ""
	@echo "Run 'make deploy-pi' to automate this"

# Docker utilities
docker-shell:
	docker exec -it iec62443-analyzer /bin/sh

docker-logs:
	docker logs -f iec62443-analyzer

docker-stats:
	docker stats iec62443-analyzer

# Frontend development
frontend-dev:
	cd frontend && npm run dev

frontend-build:
	cd frontend && npm run build

frontend-lint:
	cd frontend && npm run lint

# Full setup (for CI/CD)
full-setup: install-deps build docker-build
	@echo "Full setup complete!"
	@echo "Run 'make docker-run' to start the application"
