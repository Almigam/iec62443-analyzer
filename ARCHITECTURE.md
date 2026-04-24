# IEC 62443-3-3 Analyzer - Architecture

## System Overview

This is a compliance analyzer application designed for Raspberry Pi 5 acting as a secure edge node in an industrial OT (Operational Technology) network. It implements the 7 Foundational Requirements (FR1-FR7) of IEC 62443-3-3.

## Technology Stack

### Backend
- **Language**: Go 1.22
- **Framework**: Gin (HTTP framework)
- **Database**: SQLite (single-node, embedded)
- **Authentication**: JWT + Bcrypt
- **TLS**: TLS 1.2+ with modern cipher suites

### Frontend
- **Framework**: React 19
- **Build Tool**: Vite
- **HTTP Client**: Axios
- **Charts**: Recharts

### Infrastructure
- **Containerization**: Docker
- **OS**: Raspberry Pi OS 64-bit (hardened)
- **Process Manager**: systemd
- **Security**: UFW firewall, fail2ban, kernel hardening

## Architecture Components

```
┌─────────────────────────────────────────────────────┐
│         Raspberry Pi 5 (IEC 62443 Edge Node)        │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Frontend (React + Vite)                            │
│  ├─ Dashboard.jsx (Status & Results)                │
│  ├─ ScanResults.jsx (Compliance Results)            │
│  └─ Header.jsx (Navigation)                         │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  Backend (Go + Gin)                          │   │
│  │                                              │   │
│  │  API Endpoints:                              │   │
│  │  ├─ /api/scan/fr1-7 (Compliance Checks)     │   │
│  │  ├─ /api/scan/all (Full Scan)               │   │
│  │  ├─ /api/results (History)                  │   │
│  │  └─ /healthz (Health Check)                 │   │
│  │                                              │   │
│  │  Analyzers (Internal):                       │   │
│  │  ├─ FR1: Identification & Authentication    │   │
│  │  ├─ FR2: Use Control & RBAC                 │   │
│  │  ├─ FR3: System Integrity                   │   │
│  │  ├─ FR4: Data Confidentiality               │   │
│  │  ├─ FR5: Restricted Data Flow               │   │
│  │  ├─ FR6: Timely Response to Events          │   │
│  │  └─ FR7: Resource Availability              │   │
│  │                                              │   │
│  │  Authentication (FR1):                       │   │
│  │  ├─ User Registration                        │   │
│  │  ├─ Password Hashing (Bcrypt)               │   │
│  │  └─ JWT Token Validation                    │   │
│  │                                              │   │
│  │  Authorization (FR2):                        │   │
│  │  ├─ Role-Based Access Control (RBAC)        │   │
│  │  ├─ Admin, Engineer, Operator Roles         │   │
│  │  └─ Permission Enforcement                  │   │
│  │                                              │   │
│  │  Logging & Monitoring (FR6):                 │   │
│  │  ├─ Security Event Logging                  │   │
│  │  ├─ Failed Login Tracking                   │   │
│  │  ├─ Account Lockout (After 3 Failed)        │   │
│  │  └─ Alert System                            │   │
│  │                                              │   │
│  │  Resource Monitoring (FR7):                  │   │
│  │  ├─ CPU Usage                               │   │
│  │  ├─ Memory Usage                            │   │
│  │  ├─ Disk Space                              │   │
│  │  └─ Service Health Checks                   │   │
│  │                                              │   │
│  │  Database (SQLite):                          │   │
│  │  ├─ Users & Roles                           │   │
│  │  ├─ Scan Results                            │   │
│  │  ├─ Security Logs                           │   │
│  │  └─ System Configuration                    │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  OS Security Layer:                                 │
│  ├─ UFW Firewall (Ports: 443 only)                 │
│  ├─ SSH Hardening (Key-based auth)                │
│  ├─ Fail2ban (Intrusion Detection)                │
│  ├─ Automatic Security Updates                    │
│  ├─ System Logging & Rotation                     │
│  ├─ Kernel Parameter Hardening                    │
│  └─ Non-root Service User (analyzer)              │
│                                                      │
└─────────────────────────────────────────────────────┘
         │
         │ HTTPS (TLS 1.2+)
         │ Port 443
         │
    ┌────┴────────────────────────────────┐
    │                                      │
┌───┴──────────────┐         ┌───────────┴───┐
│  Local OT        │         │   Management  │
│  Network         │         │   Network     │
│                  │         │  (SSH Only)   │
│ - PLCs           │         │               │
│ - Sensors        │         │ - Engineers   │
│ - Controllers    │         │ - Operators   │
└──────────────────┘         └───────────────┘
```

## Data Flow

### Authentication Flow (FR1)
```
User Login Request
    ↓
Password Validation (Bcrypt)
    ↓
JWT Token Generation
    ↓
HTTPS Response with Token
    ↓
Subsequent Requests with Authorization Header
```

### Scan Execution Flow
```
API Request (/api/scan/fr[1-7])
    ↓
Load Analyzer Module
    ↓
Execute Security Checks
    ↓
Store Results in SQLite
    ↓
Log Events (FR6)
    ↓
Return JSON Response
```

### Security Event Flow (FR6)
```
Security Event Detected
    ↓
Log to SecurityLog Table
    ↓
Check Severity Level
    ↓
If Critical: Trigger Alert & Account Lockout
    ↓
Store in Audit Trail
```

## IEC 62443-3-3 Compliance Mapping

### FR1: Identification and Authentication Control
- User authentication with strong passwords (≥12 chars, complexity)
- Bcrypt password hashing
- HTTPS/TLS for secure transport
- Failed login attempt tracking
- Account lockout mechanism (3 attempts → 30 min lockout)

### FR2: Use Control
- Role-Based Access Control (RBAC)
- Roles: Admin, Engineer, Operator
- Permission-based endpoint access
- Audit trail for authorization decisions

### FR3: System Integrity
- File integrity monitoring for critical files
- Configuration file protection (700 permissions)
- TLS certificate validation
- Protected directories (/certs, /data, /logs)

### FR4: Data Confidentiality
- HTTPS/TLS 1.2+ enforcement
- Password hashing at rest
- No plaintext secrets in configuration
- Protected endpoints (no debug routes)

### FR5: Restricted Data Flow
- UFW firewall with default deny policy
- Only HTTPS (443) open to external
- SSH only from management subnet
- Network segmentation for OT zone

### FR6: Timely Response to Events
- Real-time security event logging
- Failed login monitoring
- Account lockout procedures
- Alert generation for critical events
- Audit trail retention (30+ days)

### FR7: Resource Availability
- Resource monitoring (CPU, RAM, disk)
- Systemd restart policy (auto-recovery)
- Connection timeouts (15s read/write)
- Rate limiting on authentication endpoints
- Health check endpoints (/healthz)

## Security Features

### Transport Security
- TLS 1.2+ minimum
- Strong cipher suites only
- Perfect Forward Secrecy support
- HSTS headers

### Authentication
- Strong password requirements
- Bcrypt hashing (cost factor 10)
- JWT token-based sessions (8-hour expiry)
- Multi-factor ready (framework in place)

### Authorization
- Fine-grained RBAC
- Principle of least privilege
- Role-based endpoint protection

### Logging & Monitoring
- Structured security event logging
- Real-time alert generation
- Audit trail for compliance
- Log rotation and archival

### Resilience (FR7)
- Automatic service restart on failure
- Health monitoring with systemd
- Resource limits to prevent DoS
- Graceful degradation

## Deployment

### Local Development
```bash
go run ./cmd/main.go
```

### Docker Deployment
```bash
docker-compose up -d
```

### Bare Metal (Raspberry Pi)
1. Run `raspberry-pi-config/os-hardening.sh`
2. Run `raspberry-pi-config/tls-setup.sh`
3. Copy analyzer binary to `/opt/analyzer/`
4. Install systemd service: `systemd-service.service`
5. Start: `systemctl start iec62443-analyzer`

## Database Schema

### Users Table
- ID (UUID)
- Username (unique)
- Email (unique)
- PasswordHash (bcrypt)
- RoleID (FK)
- Enabled (boolean)
- FailedAttempts (counter)
- LockedUntil (timestamp)
- Timestamps

### Roles Table
- ID (UUID)
- Name (unique)
- Permissions (JSON array)
- Description

### ScanResults Table
- ID (UUID)
- Timestamp (indexed)
- FRID (FR1-FR7)
- SRID (SR identifier)
- Status (PASS/FAIL/WARNING)
- Details (text)
- SLLevel (1-4)

### SecurityLogs Table
- ID (UUID)
- Timestamp (indexed)
- EventType (LOGIN_FAILED, ACCESS_DENIED, etc)
- UserID
- IPAddress
- Message
- Severity (INFO, WARN, CRITICAL)

## Monitoring & Observability

- Structured JSON logging via journald
- Real-time security alerts
- Historical compliance scan results
- System resource monitoring
- Failed authentication tracking

## Future Enhancements

- LDAP/Active Directory integration
- Certificate pinning for API clients
- Hardware security module (HSM) support
- Blockchain audit trail
- Machine learning anomaly detection
- Multi-factor authentication (MFA)
- REST API rate limiting per user
