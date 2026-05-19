#!/bin/bash
set -e

# Create required runtime directories
mkdir -p /run/cups /var/log/cups /var/spool/cups

# Start avahi-daemon (needed by cups-browsed for dnssd)
avahi-daemon --daemonize --no-chroot 2>/dev/null || true

# Start CUPS
/usr/sbin/cupsd

# Start cups-browsed (vulnerable — listens on UDP 631)
/usr/sbin/cups-browsed &

# Minimal Python status page on port 8080
python3 /opt/status_server.py &

# Keep container alive and tail CUPS log
tail -f /var/log/cups/error_log 2>/dev/null || tail -f /dev/null
