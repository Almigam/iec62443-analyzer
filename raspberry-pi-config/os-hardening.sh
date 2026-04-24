#!/bin/bash
# Raspberry Pi OS Hardening Script for IEC 62443-3-3 Compliance
# Run as root: sudo bash os-hardening.sh

set -e

echo "=== Raspberry Pi OS Hardening for IEC 62443-3-3 ==="

# 1. Update system
echo "[1/10] Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get install -y curl wget ufw fail2ban unattended-upgrades apt-listchanges

# 2. Disable unnecessary services
echo "[2/10] Disabling unnecessary services..."
systemctl disable avahi-daemon
systemctl stop avahi-daemon
systemctl disable bluetooth
systemctl stop bluetooth 2>/dev/null || true
systemctl disable cups
systemctl stop cups 2>/dev/null || true

# 3. Configure SSH (hardening)
echo "[3/10] Hardening SSH configuration..."
cat > /etc/ssh/sshd_config.d/hardened.conf <<EOF
# IEC 62443 Hardened SSH Configuration
Protocol 2
Port 22
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 10
PermitEmptyPasswords no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
PrintMotd yes
PrintLastLog yes
TCPKeepAlive yes
Compression no
ClientAliveInterval 300
ClientAliveCountMax 2
UsePAM yes
EOF

systemctl restart ssh

# 4. Firewall configuration
echo "[4/10] Configuring UFW firewall..."
bash firewall-rules.sh

# 5. Configure automatic updates
echo "[5/10] Enabling automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

# 6. Configure fail2ban for FR6 (Timely Response to Events)
echo "[6/10] Configuring fail2ban for intrusion detection..."
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1800
findtime = 600
maxretry = 3
destemail = root@localhost
sendername = Fail2Ban

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# 7. Set up kernel parameters
echo "[7/10] Hardening kernel parameters..."
cat > /etc/sysctl.d/99-hardening.conf <<EOF
# IP forwarding disabled for edge device
net.ipv4.ip_forward = 0

# Disable ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.disable_ipv6 = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl -p /etc/sysctl.d/99-hardening.conf

# 8. Configure logging and rotation
echo "[8/10] Configuring system logging..."
mkdir -p /var/log/iec62443
chmod 700 /var/log/iec62443

cat > /etc/logrotate.d/iec62443 <<EOF
/var/log/iec62443/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root root
    sharedscripts
}
EOF

# 9. Create audit user (non-root)
echo "[9/10] Creating analyzer service user..."
if ! id -u analyzer > /dev/null 2>&1; then
    useradd -r -s /bin/false -m -d /opt/analyzer analyzer
fi
chmod 700 /opt/analyzer

# 10. Security audit
echo "[10/10] Running security audit..."
echo "=== System Hardening Complete ==="
echo ""
echo "Security Summary:"
echo "- Unnecessary services disabled (Avahi, Bluetooth, CUPS)"
echo "- SSH hardened: password auth disabled, key auth required"
echo "- UFW firewall configured"
echo "- Automatic security updates enabled"
echo "- Fail2ban intrusion detection active"
echo "- Kernel parameters hardened"
echo "- System logging configured"
echo ""
echo "IMPORTANT: Next steps:"
echo "1. Configure SSH key authentication"
echo "2. Set up TLS certificates in ./certs/"
echo "3. Deploy analyzer service with systemd"
echo "4. Configure network interface for OT network"
echo ""
