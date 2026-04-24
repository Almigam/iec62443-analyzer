# IEC 62443-3-3 Analyzer - Setup Guide

## Prerequisites

### For Development
- Go 1.22+
- Node.js 18+
- Git
- Docker (optional)

### For Raspberry Pi Deployment
- Raspberry Pi 5 with 4GB+ RAM
- Raspberry Pi OS 64-bit (latest)
- Internet connection for initial setup
- SSH access to the Pi
- 2GB+ free disk space

## Development Setup

### 1. Clone Repository
```bash
git clone https://github.com/almigam/iec62443-analyzer.git
cd iec62443-analyzer
```

### 2. Backend Setup (Go)

```bash
cd backend

# Download dependencies
go mod download

# Build the application
go build -o analyzer ./cmd/main.go

# Run locally
./analyzer

# Expected output:
# 2024/04/24 10:00:00 Starting IEC 62443-3-3 Analyzer on port 443 (HTTPS)
# 2024/04/24 10:00:00 Environment: development
```

### 3. Generate Development TLS Certificates

```bash
bash ../raspberry-pi-config/tls-setup.sh
```

Creates:
- `certs/server.crt` - TLS certificate
- `certs/server.key` - Private key

### 4. Frontend Setup (React)

```bash
cd frontend

# Install dependencies
npm install

# Run development server
npm run dev

# Expected output:
# VITE v8.0.1  ready in XXX ms
# ➜  Local:   http://localhost:5173/
```

### 5. Access the Application

**Frontend:** https://localhost:5173/ (in development)
**Backend API:** https://localhost:443/api/

Note: Browser may warn about self-signed certificate (expected for development)

## Docker Deployment

### 1. Build Docker Image
```bash
docker build -t iec62443-analyzer:latest .
```

### 2. Create Environment File
```bash
cat > .env <<EOF
JWT_SECRET=your-secret-key-change-in-production
ENV=production
EOF
```

### 3. Run with Docker Compose
```bash
docker-compose up -d
```

### 4. View Logs
```bash
docker logs -f iec62443-analyzer
```

### 5. Access Application
- Backend API: https://localhost:443/api/
- Health check: https://localhost:443/healthz

## Raspberry Pi OS Installation

### Phase 1: OS Preparation (30 minutes)

#### 1.1 Install Raspberry Pi OS

**Using Raspberry Pi Imager:**
1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Select: Raspberry Pi OS (64-bit)
3. Write to microSD card
4. Insert card, power on

#### 1.2 Initial Configuration
```bash
# SSH into Pi
ssh pi@192.168.1.x

# Change default password
passwd

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Enable SSH (if not already enabled)
sudo raspi-config
# Navigate to: Interface Options > SSH > Enable
```

### Phase 2: OS Hardening (45 minutes)

#### 2.1 Run Hardening Script
```bash
# Copy hardening scripts to Pi
scp -r raspberry-pi-config/ pi@192.168.1.x:~/

# SSH into Pi
ssh pi@192.168.1.x

# Run hardening script (requires root)
sudo bash ~/raspberry-pi-config/os-hardening.sh

# Follow the prompts
# This will take ~15-20 minutes
```

#### 2.2 Setup TLS Certificates
```bash
# Generate self-signed certificates
bash ~/raspberry-pi-config/tls-setup.sh

# For production: obtain CA-signed certificates
# See OS-HARDENING.md for instructions
```

#### 2.3 Configure SSH Access (disable password auth)
```bash
# On your local machine, generate ED25519 key
ssh-keygen -t ed25519 -f ~/.ssh/pi_key -N ""

# Copy to Pi
ssh-copy-id -i ~/.ssh/pi_key.pub pi@192.168.1.x

# Test key-based login
ssh -i ~/.ssh/pi_key pi@192.168.1.x

# Confirm password auth is disabled:
sudo grep "PasswordAuthentication" /etc/ssh/sshd_config.d/hardened.conf
```

### Phase 3: Application Deployment (30 minutes)

#### 3.1 Build Application

**Option A: Build on Raspberry Pi (slow)**
```bash
ssh -i ~/.ssh/pi_key pi@192.168.1.x

# Install Go
curl -OL https://go.dev/dl/go1.22.linux-arm64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.22.linux-arm64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Clone and build
git clone https://github.com/almigam/iec62443-analyzer.git
cd iec62443-analyzer/backend
go build -o analyzer ./cmd/main.go
```

**Option B: Build on local machine (recommended)**
```bash
# On your local machine
cd backend
GOOS=linux GOARCH=arm64 go build -o analyzer ./cmd/main.go

# Copy to Pi
scp -i ~/.ssh/pi_key analyzer pi@192.168.1.x:~/
```

#### 3.2 Setup Application Directory
```bash
# SSH into Pi
ssh -i ~/.ssh/pi_key pi@192.168.1.x

# Create application directory
sudo mkdir -p /opt/analyzer/{certs,data,logs}
sudo chown analyzer:analyzer /opt/analyzer
sudo chmod -R 700 /opt/analyzer

# Copy analyzer binary
sudo cp ~/analyzer /opt/analyzer/
sudo chown analyzer:analyzer /opt/analyzer/analyzer
sudo chmod 755 /opt/analyzer/analyzer

# Copy TLS certificates
sudo cp ~/certs/server.crt /opt/analyzer/certs/
sudo cp ~/certs/server.key /opt/analyzer/certs/
sudo chown -R analyzer:analyzer /opt/analyzer/certs/
sudo chmod -R 600 /opt/analyzer/certs/
```

#### 3.3 Install Systemd Service
```bash
# Copy service file
sudo cp ~/raspberry-pi-config/systemd-service.service \
  /etc/systemd/system/iec62443-analyzer.service

# Enable service
sudo systemctl daemon-reload
sudo systemctl enable iec62443-analyzer

# Start service
sudo systemctl start iec62443-analyzer

# Check status
sudo systemctl status iec62443-analyzer
```

#### 3.4 Verify Deployment
```bash
# Check service is running
sudo systemctl is-active iec62443-analyzer

# View recent logs
sudo journalctl -u iec62443-analyzer -n 20

# Test API endpoint (from another machine)
curl -k https://192.168.1.x/api/health
# Expected response: {"status":"healthy"}
```

### Phase 4: Frontend Setup (Optional)

#### 4.1 Build Frontend (on local machine)
```bash
cd frontend
npm install
npm run build

# Output in: frontend/dist/
```

#### 4.2 Serve Frontend (two options)

**Option A: Via Backend (built-in)**
```bash
# Copy dist to analyzer
sudo cp -r frontend/dist/* /opt/analyzer/static/
```

**Option B: Via Nginx (recommended)**
```bash
# SSH into Pi
ssh -i ~/.ssh/pi_key pi@192.168.1.x

# Install Nginx
sudo apt-get install -y nginx

# Configure reverse proxy
sudo cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    ssl_certificate /opt/analyzer/certs/server.crt;
    ssl_certificate_key /opt/analyzer/certs/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /opt/frontend/dist;
    index index.html;

    # Frontend
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api/ {
        proxy_pass https://localhost:8443/api/;
        proxy_ssl_verify off;
    }
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    return 301 https://$server_name$request_uri;
}
EOF

sudo systemctl restart nginx
```

### Phase 5: Verification and Testing

#### 5.1 Network Connectivity
```bash
# From another machine
ping 192.168.1.x
# Should respond

# SSH access
ssh -i ~/.ssh/pi_key pi@192.168.1.x
# Should connect without password
```

#### 5.2 API Testing
```bash
# Health check
curl -k https://192.168.1.x/healthz

# Run FR1 scan
curl -k https://192.168.1.x/api/scan/fr1

# Run all scans
curl -k https://192.168.1.x/api/scan/all

# Get results
curl -k https://192.168.1.x/api/results
```

#### 5.3 Security Verification
```bash
ssh -i ~/.ssh/pi_key pi@192.168.1.x

# Check firewall
sudo ufw status

# Check running services
sudo ss -tlnp | grep LISTEN

# Check analyzer service
sudo systemctl status iec62443-analyzer

# Check fail2ban
sudo fail2ban-client status

# Review logs
sudo journalctl -p warn -n 20
```

## Updating the Application

### Update Binary
```bash
# Build new version locally
cd backend
GOOS=linux GOARCH=arm64 go build -o analyzer ./cmd/main.go

# Stop service on Pi
ssh -i ~/.ssh/pi_key pi@192.168.1.x \
  sudo systemctl stop iec62443-analyzer

# Copy new binary
scp -i ~/.ssh/pi_key analyzer pi@192.168.1.x:~/

# Update on Pi
ssh -i ~/.ssh/pi_key pi@192.168.1.x \
  sudo cp ~/analyzer /opt/analyzer/analyzer

# Restart service
ssh -i ~/.ssh/pi_key pi@192.168.1.x \
  sudo systemctl start iec62443-analyzer
```

### Update Frontend
```bash
# Build new version
cd frontend
npm run build

# Copy to Pi
scp -r frontend/dist/* pi@192.168.1.x:~/dist/

# Update on Pi
ssh -i ~/.ssh/pi_key pi@192.168.1.x \
  sudo cp -r ~/dist/* /opt/frontend/
```

## Troubleshooting

### Service won't start
```bash
# Check logs
sudo journalctl -u iec62443-analyzer -f

# Verify permissions
ls -la /opt/analyzer/

# Check TLS certificates
ls -la /opt/analyzer/certs/
```

### Can't access via HTTPS
```bash
# Check if port 443 is open
sudo ss -tlnp | grep 443

# Check firewall
sudo ufw status

# Test locally
curl -k https://localhost:443/healthz
```

### Analyzer crashes repeatedly
```bash
# Check disk space
df -h /

# Check memory
free -h

# Check for core dumps
dmesg | tail -20
```

## Security Checklist

- [ ] Default 'pi' user disabled
- [ ] SSH key-based authentication enabled
- [ ] SSH password authentication disabled
- [ ] Firewall enabled with proper rules
- [ ] TLS certificates installed
- [ ] Fail2ban active and monitoring
- [ ] Analyzer service running as non-root
- [ ] Database directory permissions: 700
- [ ] Certs directory permissions: 700
- [ ] Logs rotated and monitored
- [ ] System updates applied

## Performance Monitoring

### Monitor Service
```bash
# Real-time logs
sudo journalctl -u iec62443-analyzer -f

# Resource usage
top -p $(pgrep analyzer)

# Disk usage
du -sh /opt/analyzer/
```

### Monitor System
```bash
# CPU temperature (Raspberry Pi specific)
vcgencmd measure_temp

# Disk space
df -h

# Memory
free -h

# Uptime
uptime
```

## Next Steps

1. Review [ARCHITECTURE.md](ARCHITECTURE.md) for system design
2. Read [OS-HARDENING.md](OS-HARDENING.md) for security details
3. Configure users and roles via API
4. Run compliance scans
5. Monitor logs and security events
6. Plan regular maintenance

## Support

For issues or questions:
1. Check application logs: `sudo journalctl -u iec62443-analyzer`
2. Review OS logs: `sudo journalctl -p err`
3. Check GitHub Issues: https://github.com/almigam/iec62443-analyzer/issues
