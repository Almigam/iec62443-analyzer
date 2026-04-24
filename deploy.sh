#!/bin/bash
# Quick deployment script for Raspberry Pi
# Usage: ./deploy.sh [pi-host] [optional-branch]

set -e

PI_HOST="${1:-pi@192.168.1.x}"
BRANCH="${2:-main}"

echo "=== IEC 62443-3-3 Analyzer Deployment ==="
echo "Target: $PI_HOST"
echo "Branch: $BRANCH"
echo ""

# Step 1: Build
echo "[1/5] Building application for Raspberry Pi..."
make build-pi

# Step 2: Copy binary
echo "[2/5] Copying binary to Raspberry Pi..."
scp -i ~/.ssh/pi_key backend/analyzer $PI_HOST:~/analyzer

# Step 3: Stop service
echo "[3/5] Stopping analyzer service..."
ssh -i ~/.ssh/pi_key $PI_HOST "sudo systemctl stop iec62443-analyzer 2>/dev/null || true"

# Step 4: Deploy binary
echo "[4/5] Deploying new binary..."
ssh -i ~/.ssh/pi_key $PI_HOST "sudo cp ~/analyzer /opt/analyzer/analyzer && sudo chown analyzer:analyzer /opt/analyzer/analyzer"

# Step 5: Start service
echo "[5/5] Starting analyzer service..."
ssh -i ~/.ssh/pi_key $PI_HOST "sudo systemctl start iec62443-analyzer"

echo ""
echo "=== Deployment Complete ==="
echo "Status: $(ssh -i ~/.ssh/pi_key $PI_HOST 'sudo systemctl is-active iec62443-analyzer')"
echo "Logs: ssh -i ~/.ssh/pi_key $PI_HOST 'sudo journalctl -u iec62443-analyzer -f'"
