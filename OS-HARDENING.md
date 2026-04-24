# Raspberry Pi OS Hardening for IEC 62443-3-3

This document describes the operating system hardening applied to Raspberry Pi 5 OS to meet IEC 62443-3-3 foundational requirements.

## Hardening Layers

### 1. Network Security (FR5 - Restricted Data Flow)

#### UFW Firewall Configuration
```bash
sudo bash raspberry-pi-config/firewall-rules.sh
```

**Rules Applied:**
- Default deny incoming (except allowed ports)
- Default allow outgoing
- HTTPS (443) enabled for analyzer
- SSH (22) only from management subnet (192.168.1.0/24)
- HTTP (80) explicitly blocked
- Rate limiting on SSH (anti-brute force)
- All other ports blocked

**Firewall Status:**
```bash
sudo ufw status verbose
```

### 2. SSH Hardening (FR1 - Identification and Authentication)

**Configuration:** `/etc/ssh/sshd_config.d/hardened.conf`

```
✓ Protocol 2 only
✓ PermitRootLogin no
✓ PasswordAuthentication no (key-based only)
✓ PubkeyAuthentication yes
✓ MaxAuthTries 3 (brute force protection)
✓ MaxSessions 10
✓ X11Forwarding no
✓ ClientAliveInterval 300 (5 min timeout)
✓ ClientAliveCountMax 2
✓ Compression no
```

**Key-Based Authentication Setup:**
```bash
# Generate key pair on client (not on Pi)
ssh-keygen -t ed25519

# Copy public key to Pi
ssh-copy-id -i ~/.ssh/id_ed25519.pub pi@192.168.1.x

# Connect (no password needed)
ssh -i ~/.ssh/id_ed25519 pi@192.168.1.x
```

### 3. Service Hardening (FR7 - Resource Availability)

**Disabled Services:**
- Avahi (mDNS) - not needed in controlled OT network
- Bluetooth - security risk for industrial setting
- CUPS (printing) - unnecessary for edge device

**Remaining Services:**
- systemd-journald (logging)
- networkd or dhcpcd (networking)
- analyzer (custom application)

### 4. Automatic Security Updates

**Configuration:** Unattended-Upgrades

```bash
# Automatic daily checks
# Only installs security updates
# Logs all activities to syslog
# Optional: automatic reboot for kernel updates (disabled by default)
```

**Check update status:**
```bash
sudo apt list --upgradable
```

### 5. Intrusion Detection (FR6 - Timely Response to Events)

**Fail2ban Configuration**

Monitors and blocks:
- Multiple failed SSH attempts
- Failed application logins
- DDoS-like patterns

**Default Rules:**
```
bantime: 1800 seconds (30 minutes)
findtime: 600 seconds (10 minutes window)
maxretry: 3 failed attempts
```

**View banned IPs:**
```bash
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip 192.168.x.x
```

### 6. Kernel Hardening (FR3/FR4 - System & Data Protection)

**File:** `/etc/sysctl.d/99-hardening.conf`

```
✓ ip_forward = 0 (no IP routing)
✓ tcp_syncookies = 1 (SYN flood protection)
✓ rp_filter = 1 (reverse path filtering)
✓ send_redirects = 0 (prevent ICMP redirects)
✓ icmp_echo_ignore_all = 1 (ignore ping requests)
✓ IPv6 disabled if not needed
```

**Apply changes:**
```bash
sudo sysctl -p /etc/sysctl.d/99-hardening.conf
```

### 7. File System Permissions (FR3 - System Integrity)

**Analyzer Directories:**
```bash
# Owner: analyzer (non-root)
# Permissions: 700 (rwx------)
# This restricts access to the service user only

/opt/analyzer/
├── certs/        (700) - TLS certificates
├── data/         (700) - SQLite database
└── logs/         (700) - Application logs
```

**Set permissions:**
```bash
sudo mkdir -p /opt/analyzer/{certs,data,logs}
sudo chown -R analyzer:analyzer /opt/analyzer
sudo chmod -R 700 /opt/analyzer
```

### 8. System Logging (FR6 - Timely Response to Events)

**Journald Configuration**

Logs are stored in:
- `/var/log/journal/` (persistent)
- `/run/log/journal/` (runtime)

**View analyzer logs:**
```bash
sudo journalctl -u iec62443-analyzer -f
```

**Log rotation for analyzer:**
```bash
# File: /etc/logrotate.d/iec62443
# Rotates daily, keeps 30 days, compresses old logs
```

### 9. User Management (FR1 - Identification and Authentication)

**Default User:**
```bash
# Disable default 'pi' user
sudo usermod -L pi
sudo usermod -s /usr/sbin/nologin pi
```

**Create named accounts:**
```bash
# Example: engineer user
sudo useradd -m -s /bin/bash engineer
sudo passwd engineer  # Set strong password (≥12 chars, complexity)
```

**Sudo configuration:**
```bash
# Only specific users can use sudo
# Requires password re-entry
```

### 10. TLS/SSL Certificates (FR4 - Data Confidentiality)

**Setup Self-Signed Certificate:**
```bash
bash raspberry-pi-config/tls-setup.sh
```

**For Production:**
Replace self-signed with CA-signed certificate:
```bash
# 1. Generate CSR (Certificate Signing Request)
openssl req -new -key /opt/analyzer/certs/server.key \
  -out /opt/analyzer/certs/server.csr

# 2. Submit to Certificate Authority (Let's Encrypt, GlobalSign, etc.)

# 3. Replace server.crt with CA-signed certificate
sudo cp /path/to/ca-signed.crt /opt/analyzer/certs/server.crt
sudo chown analyzer:analyzer /opt/analyzer/certs/server.crt
sudo chmod 644 /opt/analyzer/certs/server.crt
```

## Compliance Checklist

### FR1: Identification and Authentication Control
- [x] No default accounts
- [x] Strong password policy (≥12 chars, complexity)
- [x] SSH key-based authentication only
- [x] Account lockout after failed attempts
- [x] HTTPS/TLS enforced

### FR2: Use Control
- [x] SSH sudo access restricted
- [x] Named user accounts with specific roles
- [x] Non-root service user (analyzer)
- [x] Permission-based process execution

### FR3: System Integrity
- [x] File system permissions restricted
- [x] Critical directories (certs, data) protected (700)
- [x] System binaries owned by root
- [x] Configuration files immutable during runtime

### FR4: Data Confidentiality
- [x] HTTPS/TLS 1.2+ enforced
- [x] SSH key encryption (ED25519)
- [x] No plaintext credentials in logs
- [x] Log files readable only by root/analyzer

### FR5: Restricted Data Flow
- [x] UFW firewall enabled with deny-by-default
- [x] Only HTTPS (443) open
- [x] SSH restricted to management subnet
- [x] No unnecessary services listening
- [x] Network segmentation in place

### FR6: Timely Response to Events
- [x] Systemd-journald logging enabled
- [x] Fail2ban intrusion detection active
- [x] Security event alerting configured
- [x] Audit trails stored (30+ days)

### FR7: Resource Availability
- [x] Automatic service restart on failure
- [x] Disk space monitoring (log rotation)
- [x] Memory limits configured
- [x] CPU quota enforcement
- [x] Graceful shutdown timeouts

## Hardening Execution

### Complete Hardening Setup
```bash
cd /path/to/iec62443-analyzer

# 1. OS Hardening (requires root)
sudo bash raspberry-pi-config/os-hardening.sh

# 2. TLS Certificate Setup
bash raspberry-pi-config/tls-setup.sh

# 3. Deploy analyzer binary
sudo cp ./analyzer /opt/analyzer/
sudo chown analyzer:analyzer /opt/analyzer/analyzer
sudo chmod 755 /opt/analyzer/analyzer

# 4. Install systemd service
sudo cp raspberry-pi-config/systemd-service.service \
  /etc/systemd/system/iec62443-analyzer.service

# 5. Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable iec62443-analyzer
sudo systemctl start iec62443-analyzer

# 6. Verify
sudo systemctl status iec62443-analyzer
sudo journalctl -u iec62443-analyzer -n 20
```

## Post-Hardening Verification

```bash
# 1. Firewall status
sudo ufw status verbose

# 2. Open ports (should only show 443 and 22 from restricted sources)
sudo ss -tlnp

# 3. Failed login attempts
sudo fail2ban-client status sshd

# 4. System updates
sudo apt list --upgradable

# 5. Service status
sudo systemctl status iec62443-analyzer

# 6. Recent security logs
sudo journalctl -p warn -n 50

# 7. Disk space
df -h

# 8. Running processes
ps aux | grep analyzer
```

## Maintenance

### Monthly Tasks
- Review security logs for anomalies
- Check for available security updates
- Verify firewall rules are in place
- Test backup procedures

### Quarterly Tasks
- Review and update SSH key pair
- Audit user accounts and permissions
- Update system hardening configuration
- Perform security vulnerability scan

### Annually
- Renew TLS certificate (or on CA expiration)
- Full security audit
- Update hardening scripts
- Review and update compliance documentation

## Troubleshooting

### Can't connect via SSH
```bash
# Check SSH service
sudo systemctl status ssh

# View SSH logs
sudo journalctl -u ssh -f

# Restart SSH
sudo systemctl restart ssh
```

### Analyzer service not starting
```bash
# Check service status
sudo systemctl status iec62443-analyzer

# View service logs
sudo journalctl -u iec62443-analyzer -f

# Check permissions on /opt/analyzer
ls -la /opt/analyzer/
```

### Firewall blocking legitimate traffic
```bash
# Check rules
sudo ufw status verbose

# Temporarily disable (for debugging only)
sudo ufw disable

# Enable again after debugging
sudo ufw enable
```

## References

- IEC 62443-3-3:2023 Security Requirements
- Raspberry Pi OS Documentation
- Linux Hardening Guide (NSA CISA)
- CIS Benchmarks for Debian/Linux
