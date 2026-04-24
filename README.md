# IEC 62443-3-3 Analyzer for Raspberry Pi

## Overview

A comprehensive compliance analyzer for Raspberry Pi 5 acting as a secure edge node in industrial OT (Operational Technology) networks. This application implements the **7 Foundational Requirements (FR1-FR7) of IEC 62443-3-3** standard.

## Key Features

✅ **FR1: Identification & Authentication Control**
- Strong password requirements (≥12 chars, complexity)
- Bcrypt password hashing
- HTTPS/TLS 1.2+ enforcement
- Failed login tracking & account lockout

✅ **FR2: Use Control (RBAC)**
- Role-Based Access Control (Admin, Engineer, Operator)
- Permission-based authorization
- Principle of least privilege

✅ **FR3: System Integrity**
- File integrity monitoring
- Configuration protection
- Protected critical files (certs, data, logs)

✅ **FR4: Data Confidentiality**
- HTTPS/TLS enforcement
- Password hashing at rest
- No plaintext secrets
- Protected API endpoints

✅ **FR5: Restricted Data Flow**
- UFW firewall with deny-by-default policy
- Only port 443 (HTTPS) open
- SSH restricted to management subnet
- Network segmentation for OT zone

✅ **FR6: Timely Response to Events**
- Real-time security event logging
- Failed login monitoring
- Account lockout procedures
- Alert generation for critical events

✅ **FR7: Resource Availability**
- CPU, RAM, disk monitoring
- Automatic service restart
- Health check endpoints
- Resource limits via systemd

## Technology Stack

| Component | Technology |
|-----------|------------|
| **Backend** | Go 1.22 + Gin |
| **Database** | SQLite (single-node) |
| **Authentication** | JWT + Bcrypt |
| **TLS** | TLS 1.2+ (4096-bit RSA) |
| **Frontend** | React 19 + Vite |
| **Container** | Docker + Docker Compose |
| **OS** | Raspberry Pi OS 64-bit (hardened) |
| **Process Manager** | systemd |
| **Firewall** | UFW |
| **IDS** | fail2ban |

## Architecture

```
Raspberry Pi 5 (IEC 62443 Edge Node)
├── Frontend (React SPA)
│   ├── Dashboard
│   ├── Scan Results
│   └── Security Alerts
├── Backend API (Go)
│   ├── /api/scan/fr1-7 (Compliance Checks)
│   ├── /api/scan/all (Full Scan)
│   ├── /api/results (History)
│   └── /healthz (Health Check)
├── Analyzers (FR1-FR7)
│   ├── FR1: Authentication Control
│   ├── FR2: Access Control
│   ├── FR3: System Integrity
│   ├── FR4: Data Confidentiality
│   ├── FR5: Restricted Flow
│   ├── FR6: Event Response
│   └── FR7: Availability
├── Database (SQLite)
│   ├── Users & Roles
│   ├── Scan Results
│   ├── Security Logs
│   └── Configuration
└── OS Security Layer
    ├── UFW Firewall
    ├── SSH Hardening
    ├── fail2ban
    ├── Kernel Hardening
    └── Automatic Updates
```

## Quick Start

### Development

```bash
# Backend
cd backend
go mod download
go build -o analyzer ./cmd/main.go
./analyzer

# Frontend (new terminal)
cd frontend
npm install
npm run dev
```

### Docker

```bash
docker-compose up -d
# Access: https://localhost
```

### Raspberry Pi

```bash
# Run hardening script
sudo bash raspberry-pi-config/os-hardening.sh

# Setup TLS
bash raspberry-pi-config/tls-setup.sh

# Deploy and run
sudo systemctl start iec62443-analyzer
```

## Configuration

Environment variables:
```bash
ENV=production                    # development/production
PORT=443                         # HTTPS port
DB_PATH=./data/iec62443.db      # SQLite database location
TLS_CERT=./certs/server.crt     # TLS certificate
TLS_KEY=./certs/server.key      # TLS private key
JWT_SECRET=your-secret-key      # JWT signing key
ALLOWED_ORIGINS=https://localhost # CORS origins
LOG_DIR=./logs                   # Application logs
```

## Security Features

### Transport Security
- TLS 1.2+ with strong cipher suites
- Perfect Forward Secrecy support
- HSTS headers

### Authentication (FR1)
- Bcrypt password hashing (cost factor 10)
- JWT token-based sessions (8-hour expiry)
- Account lockout after 3 failed attempts (30 min)
- Automatic session timeout

### Authorization (FR2)
- Fine-grained Role-Based Access Control
- Three privilege levels: Admin, Engineer, Operator
- Permission-based endpoint protection

### Logging & Monitoring (FR6)
- Structured security event logging
- Real-time alert generation
- Audit trail retention (30+ days)
- Fail2ban intrusion detection

### Resource Management (FR7)
- Memory limits: 512MB
- CPU quota: 75%
- Automatic service restart on failure
- Health monitoring

## API Endpoints

### Health Check
```bash
GET /healthz
```

### Analyzer Endpoints
```bash
GET /api/scan/fr1      # FR1: Identification & Authentication
GET /api/scan/fr2      # FR2: Use Control
GET /api/scan/fr3      # FR3: System Integrity
GET /api/scan/fr4      # FR4: Data Confidentiality
GET /api/scan/fr5      # FR5: Restricted Data Flow
GET /api/scan/fr6      # FR6: Event Response
GET /api/scan/fr7      # FR7: Resource Availability
GET /api/scan/all      # All FR scans
GET /api/results       # Historical results
```

### Response Example
```json
{
  "fr": "FR1",
  "description": "Identification and Authentication Control",
  "total_checks": 7,
  "passed": 6,
  "failed": 0,
  "warnings": 1,
  "results": [
    {
      "sr_id": "SR1.1",
      "fr_id": "FR1",
      "description": "User authentication system",
      "status": "PASS",
      "details": "User authentication system configured",
      "sl_level": 1
    }
  ]
}
```

## Directory Structure

```
.
├── backend/
│   ├── cmd/
│   │   └── main.go          # Application entry point
│   ├── internal/
│   │   ├── api/             # HTTP handlers & routes
│   │   ├── auth/            # Authentication & JWT
│   │   ├── analyzers/       # FR1-FR7 compliance checks
│   │   ├── config/          # Configuration management
│   │   ├── database/        # Database initialization
│   │   └── models/          # Data models (User, Role, etc)
│   ├── go.mod              # Go dependencies
│   └── go.sum
├── frontend/
│   ├── src/
│   │   ├── components/      # React components
│   │   │   ├── Dashboard.jsx
│   │   │   ├── ScanResults.jsx
│   │   │   └── Header.jsx
│   │   ├── App.jsx          # Main app component
│   │   └── main.jsx         # Entry point
│   ├── index.html
│   ├── package.json
│   └── vite.config.js
├── raspberry-pi-config/
│   ├── os-hardening.sh      # Full OS hardening
│   ├── firewall-rules.sh    # UFW configuration
│   ├── tls-setup.sh         # TLS certificate generation
│   └── systemd-service.service
├── docker-compose.yml       # Docker Compose config
├── Dockerfile              # Multi-stage build
├── ARCHITECTURE.md         # System design details
├── OS-HARDENING.md        # OS hardening guide
├── SETUP.md               # Deployment instructions
└── README.md              # This file
```

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design, components, and data flow
- **[OS-HARDENING.md](OS-HARDENING.md)** - OS security configuration and compliance
- **[SETUP.md](SETUP.md)** - Step-by-step deployment and configuration guide

## Compliance Checklist

| Requirement | Status | Details |
|------------|--------|---------|
| FR1: IAC | ✅ | Strong passwords, TLS, failed login tracking |
| FR2: UC | ✅ | RBAC with 3 roles, permission enforcement |
| FR3: SI | ✅ | File integrity, protected directories |
| FR4: DC | ✅ | HTTPS, password hashing, no debug endpoints |
| FR5: RDF | ✅ | UFW firewall, port 443 only, SSH restricted |
| FR6: TRE | ✅ | Event logging, alerts, lockout procedures |
| FR7: RA | ✅ | Resource monitoring, auto-restart, health checks |

## System Requirements

### Raspberry Pi
- Raspberry Pi 5 (4GB+ RAM)
- Raspberry Pi OS 64-bit (latest)
- 2GB+ free disk space
- Ethernet or WiFi connection

### Development Machine
- Go 1.22+
- Node.js 18+
- Docker (optional)
- 500MB free disk space

## Performance

On Raspberry Pi 5:
- Memory usage: ~150-200MB (running)
- CPU usage: ~5-10% (idle)
- Startup time: ~2 seconds
- API response time: <100ms

## Security Maintenance

### Monthly
- Review security logs
- Check for OS updates
- Verify firewall rules

### Quarterly
- Update SSH keys
- Audit user accounts
- Security vulnerability scan

### Annually
- Renew TLS certificates
- Full security audit
- Update hardening scripts

## Troubleshooting

### Service won't start
```bash
sudo systemctl status iec62443-analyzer
sudo journalctl -u iec62443-analyzer -f
```

### Can't access HTTPS
```bash
sudo ss -tlnp | grep 443
sudo ufw status
curl -k https://localhost:443/healthz
```

### High memory usage
```bash
sudo systemctl show iec62443-analyzer -p MemoryMax
free -h
df -h
```

## License

MIT License - See LICENSE file

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## Support

- **Documentation**: See [SETUP.md](SETUP.md) and [ARCHITECTURE.md](ARCHITECTURE.md)
- **Issues**: GitHub Issues tracker
- **Security**: Report security issues privately to maintainers

## References

- [IEC 62443-3-3:2023](https://www.iec.ch/) - Security Requirements Standard
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
- [Linux Hardening Guide](https://www.ncsc.gov.uk/collection/end-user-device-security) (NCSC/CISA)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/) - Debian/Linux

## Changelog

### v0.3.0 - Go Backend Release
- Complete migration from Python to Go
- All FR1-FR7 analyzers implemented
- TLS/HTTPS enforcement
- SQLite database with GORM
- JWT authentication
- RBAC authorization
- Security event logging
- Systemd integration
- Docker containerization
- Comprehensive OS hardening

### v0.2.0 - Initial Python Release
- Basic analyzer framework
- REST API structure
- SQLite database
- FastAPI backend

---

**Last Updated:** April 24, 2026  
**Version:** 0.3.0  
**Status:** Production Ready for Raspberry Pi OS
