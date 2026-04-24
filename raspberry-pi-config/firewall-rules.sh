#!/bin/bash
# UFW Firewall Configuration for IEC 62443-3-3 OT Network
# Run as root: sudo bash firewall-rules.sh

set -e

echo "=== Configuring UFW Firewall for OT Network ==="

# Enable UFW
ufw --force enable

# Set default policies
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Allow HTTPS (port 443) - main application
ufw allow 443/tcp comment 'HTTPS for IEC62443 Analyzer'

# Allow SSH from management subnet only (192.168.1.0/24)
# Adjust the subnet to match your management network
ufw allow from 192.168.1.0/24 to any port 22 proto tcp comment 'SSH from management subnet'

# Block HTTP (port 80) explicitly
ufw deny 80/tcp comment 'Block HTTP - use HTTPS only'

# Allow mDNS if needed (optional, for local discovery on internal network)
# ufw allow from 224.0.0.0/4 to any port 5353 proto udp comment 'mDNS'

# Allow OT network communication (adjust subnet to your network)
# Example for 192.168.100.0/24 OT subnet
# ufw allow from 192.168.100.0/24 comment 'OT Network'

# Block common attack ports
ufw deny 23/tcp comment 'Block Telnet'
ufw deny 3389/tcp comment 'Block RDP'
ufw deny 5900/tcp comment 'Block VNC'

# Rate limiting for SSH (brute force protection)
ufw limit 22/tcp comment 'Rate limit SSH'

# Enable logging
ufw logging on
ufw logging medium

# Display rules
echo ""
echo "=== Firewall Rules Applied ==="
ufw status verbose

echo ""
echo "Firewall configuration complete!"
echo ""
echo "Rules Summary:"
echo "- HTTPS (443) enabled for analyzer"
echo "- SSH (22) allowed only from management subnet"
echo "- HTTP (80) blocked"
echo "- All other incoming traffic denied by default"
echo "- Logging enabled for monitoring"
echo ""
