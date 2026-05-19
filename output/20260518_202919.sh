#!/bin/bash
# Lab: PrintMaster Pro — CUPS RCE Chain Lab
# CVEs: CVE-2024-47076, CVE-2024-47175, CVE-2024-47176, CVE-2024-47177
# Stack: Ubuntu 22.04 + CUPS (cups-browsed vulnerable version compiled from source)
# Objective (visible in app): "A print server is running on this host. Find a way to achieve Remote Code Execution."
# Note: This lab exposes the CUPS UDP 631 port and a minimal status web UI on port 8080.
# The student must bring their own tools (e.g. evilcups PoC, custom IPP/UDP packets).
# No exploit code is included — the lab is a TARGET only.
# Long build expected (~10-15 min due to cups-browsed compilation from source)

set -e

LAB_DIR="cups_rce_chain_lab"
mkdir -p "$LAB_DIR"/{app/src,cups-target}
cd "$LAB_DIR"

# -------------------------------------------------------------------------
# docker-compose.yml
# -------------------------------------------------------------------------
cat > docker-compose.yml << 'EOF'
services:
  cups-target:
    build: ./cups-target
    image: cups-rce-chain-target:1.0
    container_name: cups_target
    restart: unless-stopped
    # UDP 631: cups-browsed listens here for broadcast IPP-over-UDP (CVE-2024-47176)
    # TCP 631: CUPS web interface / IPP
    # TCP 8080: minimal status page for the student
    ports:
      - "0.0.0.0:631:631/udp"
      - "0.0.0.0:631:631/tcp"
      - "0.0.0.0:8080:8080/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    networks:
      - lab_net

  status-ui:
    build: ./app
    image: cups-rce-chain-status:1.0
    container_name: cups_status_ui
    restart: unless-stopped
    ports:
      - "0.0.0.0:8888:8888/tcp"
    networks:
      - lab_net

networks:
  lab_net:
    driver: bridge
EOF

# -------------------------------------------------------------------------
# cups-target/Dockerfile
# Installs a CUPS stack pinned to the vulnerable versions:
#   - cups-browsed <= 2.0.1  (CVE-2024-47176 / CVE-2024-47176)
#   - libcupsfilters <= 2.1b1 (CVE-2024-47076)
#   - libppd <= 2.1b1         (CVE-2024-47175)
#   - cups-filters <= 2.0.1   (CVE-2024-47177)
# All compiled from upstream tagged tarballs on GitHub.
# -------------------------------------------------------------------------
cat > cups-target/Dockerfile << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ── Build dependencies ────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget curl git ca-certificates \
        build-essential autoconf automake libtool pkg-config \
        libavahi-client-dev libavahi-common-dev \
        libgnutls28-dev libssl-dev \
        libdbus-1-dev \
        libsystemd-dev \
        zlib1g-dev \
        libusb-1.0-0-dev \
        libpam0g-dev \
        libpng-dev libjpeg-dev libtiff-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        fonts-freefont-ttf \
        poppler-utils \
        ghostscript \
        libqpdf-dev \
        libcupsimage2-dev \
        cups \
        cups-client \
        avahi-daemon \
        python3 \
        python3-pip \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# ── 1. libcupsfilters 2.1b1 (CVE-2024-47076) ─────────────────────────────
RUN wget -q https://github.com/OpenPrinting/libcupsfilters/releases/download/2.1b1/libcupsfilters-2.1b1.tar.gz \
    && tar xzf libcupsfilters-2.1b1.tar.gz \
    && cd libcupsfilters-2.1b1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && cd /build && rm -rf libcupsfilters-2.1b1*

# ── 2. libppd 2.1b1 (CVE-2024-47175) ─────────────────────────────────────
RUN wget -q https://github.com/OpenPrinting/libppd/releases/download/2.1b1/libppd-2.1b1.tar.gz \
    && tar xzf libppd-2.1b1.tar.gz \
    && cd libppd-2.1b1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && cd /build && rm -rf libppd-2.1b1*

# ── 3. cups-filters 2.0.1 (CVE-2024-47177 — foomatic-rip command injection) ──
RUN wget -q https://github.com/OpenPrinting/cups-filters/releases/download/2.0.1/cups-filters-2.0.1.tar.gz \
    && tar xzf cups-filters-2.0.1.tar.gz \
    && cd cups-filters-2.0.1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && cd /build && rm -rf cups-filters-2.0.1*

# ── 4. cups-browsed 2.0.1 (CVE-2024-47176) ───────────────────────────────
RUN wget -q https://github.com/OpenPrinting/cups-browsed/releases/download/2.0.1/cups-browsed-2.0.1.tar.gz \
    && tar xzf cups-browsed-2.0.1.tar.gz \
    && cd cups-browsed-2.0.1 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    && make -j"$(nproc)" \
    && make install \
    && cd /build && rm -rf cups-browsed-2.0.1*

# ── CUPS configuration ────────────────────────────────────────────────────
COPY cups/cupsd.conf        /etc/cups/cupsd.conf
COPY cups/cups-browsed.conf /etc/cups/cups-browsed.conf

# ── Flag ──────────────────────────────────────────────────────────────────
RUN echo "FLAG{cups_rce_chain_pwned_CVE-2024-47076_47175_47176_47177}" > /root/flag.txt \
    && chmod 600 /root/flag.txt

# ── Entrypoint ────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 631/udp 631/tcp 8080/tcp

ENTRYPOINT ["/entrypoint.sh"]
EOF

# ── CUPS daemon configuration ─────────────────────────────────────────────
mkdir -p cups-target/cups

cat > cups-target/cups/cupsd.conf << 'EOF'
# CUPS daemon configuration for vulnerable PrintMaster Pro lab
# Listens on all interfaces (required for the lab target to be reachable)
Listen 0.0.0.0:631
Listen /run/cups/cups.sock

# Allow browsing advertisements
Browsing On
BrowseLocalProtocols dnssd

# Log level
LogLevel debug

# Allow access from any host (lab environment — not a production setting)
<Location />
  Order allow,deny
  Allow all
</Location>

<Location /admin>
  Order allow,deny
  Allow all
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow all
</Location>

DefaultEncryption Never
EOF

cat > cups-target/cups/cups-browsed.conf << 'EOF'
# cups-browsed 2.0.1 configuration
# BrowseRemoteProtocols includes CUPS (UDP 631) — CVE-2024-47176 attack surface
BrowseRemoteProtocols CUPS dnssd

# Listen on UDP 631 for incoming printer advertisements from any source
# This is the entry point for the CVE-2024-47176 / CVE-2024-47175 chain
BrowseAllow all
BrowseOrder allow,deny

# CreateIPPPrinterQueues: automatically create queues for discovered IPP printers
CreateIPPPrinterQueues All

# No filtering on the source of IPP attributes — enables CVE-2024-47076 / CVE-2024-47175
IPPPrinterQueueType PPD
EOF

# ── Entrypoint script ─────────────────────────────────────────────────────
cat > cups-target/entrypoint.sh << 'EOF'
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
EOF

# ── Minimal status page served from within the cups-target container ───────
# (This is served by the cups-target itself; the status-ui container adds
#  a richer HTML front-end on port 8888.)
mkdir -p cups-target/opt 2>/dev/null || true

cat > cups-target/opt/status_server.py << 'PYEOF'
#!/usr/bin/env python3
"""
Minimal HTTP status page — runs inside cups-target on port 8080.
Shows that CUPS is running and hints at the objective.
No vulnerability lives here; it is purely informational.
"""
import http.server
import subprocess
import html

PORT = 8080

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <title>PrintMaster Pro — Print Server Status</title>
  <style>
    body {{ font-family: Arial, sans-serif; background:#1a1a2e; color:#e0e0e0; margin:0; padding:0; }}
    header {{ background:#16213e; padding:18px 32px; border-bottom:3px solid #0f3460; }}
    header h1 {{ margin:0; font-size:1.6em; color:#e94560; }}
    header span {{ color:#a0a0b0; font-size:.9em; }}
    .container {{ max-width:860px; margin:40px auto; padding:0 24px; }}
    .card {{ background:#16213e; border-radius:8px; padding:24px; margin-bottom:24px; border:1px solid #0f3460; }}
    .card h2 {{ margin-top:0; color:#e94560; }}
    .badge {{ display:inline-block; padding:3px 10px; border-radius:4px; font-size:.8em; font-weight:bold; }}
    .badge.up {{ background:#145a32; color:#58d68d; }}
    .badge.warn {{ background:#7d6608; color:#f9e79f; }}
    table {{ width:100%; border-collapse:collapse; font-size:.9em; }}
    th {{ text-align:left; color:#a0a0b0; padding:6px 10px; border-bottom:1px solid #0f3460; }}
    td {{ padding:6px 10px; border-bottom:1px solid #0f3460; }}
    .objective {{ background:#1f0a0a; border:1px solid #e94560; border-radius:8px; padding:20px 24px; }}
    .objective h2 {{ color:#e94560; margin-top:0; }}
    footer {{ text-align:center; color:#555; font-size:.8em; padding:24px; }}
  </style>
</head>
<body>
<header>
  <h1>&#128438; PrintMaster Pro</h1>
  <span>Enterprise Print Management Platform — Internal Operations Panel</span>
</header>
<div class="container">

  <div class="card">
    <h2>Service Health</h2>
    <table>
      <tr><th>Service</th><th>Status</th><th>Protocol</th><th>Port</th></tr>
      <tr>
        <td>CUPS Daemon (cupsd)</td>
        <td><span class="badge up">RUNNING</span></td>
        <td>IPP / TCP</td>
        <td>631</td>
      </tr>
      <tr>
        <td>cups-browsed</td>
        <td><span class="badge up">RUNNING</span></td>
        <td>UDP Browse / IPP</td>
        <td>631</td>
      </tr>
      <tr>
        <td>Avahi (mDNS)</td>
        <td><span class="badge warn">DEGRADED</span></td>
        <td>mDNS / DNS-SD</td>
        <td>5353</td>
      </tr>
    </table>
  </div>

  <div class="card">
    <h2>Registered Printers</h2>
    {printer_rows}
  </div>

  <div class="card">
    <h2>System Info</h2>
    <table>
      <tr><th>Component</th><th>Version</th></tr>
      <tr><td>cups-browsed</td><td>2.0.1</td></tr>
      <tr><td>libcupsfilters</td><td>2.1b1</td></tr>
      <tr><td>libppd</td><td>2.1b1</td></tr>
      <tr><td>cups-filters</td><td>2.0.1</td></tr>
      <tr><td>OS</td><td>Ubuntu 22.04 LTS</td></tr>
    </table>
  </div>

  <div class="objective">
    <h2>&#127937; Objective</h2>
    <p>
      This print server exposes a <strong>network-accessible CUPS stack</strong>.<br/>
      Identify the vulnerable services, craft the appropriate network requests, and achieve
      <strong>Remote Code Execution</strong> on this host.<br/>
      Proof of compromise: read <code>/root/flag.txt</code>.
    </p>
    <p style="color:#a0a0b0; font-size:.85em;">
      Hint: cups-browsed is listening for printer advertisements on UDP port 631.
      No credentials are required to send it a crafted packet.
    </p>
  </div>

</div>
<footer>PrintMaster Pro v3.4.1 &mdash; &copy; 2024 PrintMaster Technologies Inc.</footer>
</body>
</html>
"""

def get_printer_rows():
    try:
        out = subprocess.check_output(["lpstat", "-p"], stderr=subprocess.DEVNULL, timeout=3).decode()
        rows = ""
        for line in out.strip().splitlines():
            rows += f"<tr><td>{html.escape(line)}</td></tr>"
        if not rows:
            rows = "<tr><td style='color:#a0a0b0;'>No printers currently registered.</td></tr>"
        return f"<table><tr><th>Printer entry</th></tr>{rows}</table>"
    except Exception:
        return "<p style='color:#a0a0b0;'>No printers currently registered.</p>"

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # suppress access log noise

    def do_GET(self):
        body = HTML_TEMPLATE.format(printer_rows=get_printer_rows()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

httpd = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
httpd.serve_forever()
PYEOF

# ── app/ — richer external status/info UI (separate container, port 8888) ─
cat > app/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/
EXPOSE 8888
CMD ["python3", "src/app.py"]
EOF

cat > app/requirements.txt << 'EOF'
flask==2.3.3
Werkzeug==2.3.7
EOF

mkdir -p app/src

cat > app/src/app.py << 'PYEOF'
#!/usr/bin/env python3
"""
PrintMaster Pro — External Operations Portal
Provides a public-facing status and job submission UI.
No vulnerability lives in this container.
The attack surface is the CUPS stack in the cups-target container.
"""
from flask import Flask, render_template_string, request, redirect, url_for

app = Flask(__name__)

# Simulated job history — realistic seed data (>= 10 records)
JOB_HISTORY = [
    {"id": 1001, "user": "margaret.owens",    "doc": "Q3_FinancialReport.pdf",     "pages": 42, "printer": "HP-LaserJet-Floor2",  "status": "Completed"},
    {"id": 1002, "user": "derek.walsh",       "doc": "EmployeeHandbook_2024.pdf",  "pages": 88, "printer": "Canon-IR2630-Lobby",  "status": "Completed"},
    {"id": 1003, "user": "priya.sharma",      "doc": "ProjectProposal_Alpha.docx", "pages": 14, "printer": "HP-LaserJet-Floor2",  "status": "Completed"},
    {"id": 1004, "user": "tom.henderson",     "doc": "InvoiceBatch_Oct2024.pdf",   "pages":  6, "printer": "Xerox-WC7845-Acctg",  "status": "Completed"},
    {"id": 1005, "user": "sarah.kimura",      "doc": "MeetingNotes_20241003.txt",  "pages":  2, "printer": "HP-LaserJet-Floor2",  "status": "Completed"},
    {"id": 1006, "user": "carlos.reyes",      "doc": "DataCenter_Schematic_v3.pdf","pages": 19, "printer": "Xerox-WC7845-Acctg",  "status": "Completed"},
    {"id": 1007, "user": "linda.foster",      "doc": "LegalBrief_CaseNo4421.pdf",  "pages": 73, "printer": "Canon-IR2630-Lobby",  "status": "Completed"},
    {"id": 1008, "user": "james.oduya",       "doc": "ProductRoadmap_2025.pptx",   "pages": 31, "printer": "HP-LaserJet-Floor2",  "status": "Completed"},
    {"id": 1009, "user": "anita.bauer",       "doc": "HR_PolicyUpdate_Nov2024.pdf","pages":  8, "printer": "Xerox-WC7845-Acctg",  "status": "Failed"},
    {"id": 1010, "user": "kevin.strachan",    "doc": "NetworkAudit_Report.pdf",    "pages": 55, "printer": "Canon-IR2630-Lobby",  "status": "Completed"},
    {"id": 1011, "user": "mei.zhang",         "doc": "SalesPresentation_Q4.pptx",  "pages": 24, "printer": "HP-LaserJet-Floor2",  "status": "Queued"},
    {"id": 1012, "user": "oliver.grant",      "doc": "SupplierContract_2024.pdf",  "pages": 17, "printer": "Xerox-WC7845-Acctg",  "status": "Queued"},
]

BASE_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <title>PrintMaster Pro — Enterprise Print Management</title>
  <style>
    *{{ box-sizing:border-box; }}
    body{{ font-family:'Segoe UI',Arial,sans-serif; background:#f0f2f5; margin:0; color:#222; }}
    nav{{ background:#1a1a2e; padding:0 32px; display:flex; align-items:center; height:56px; }}
    nav .brand{{ color:#e94560; font-size:1.3em; font-weight:bold; text-decoration:none; }}
    nav a{{ color:#ccc; text-decoration:none; margin-left:28px; font-size:.95em; }}
    nav a:hover{{ color:#fff; }}
    .hero{{ background:linear-gradient(135deg,#1a1a2e,#16213e); color:#fff; padding:48px 32px 36px; }}
    .hero h1{{ margin:0 0 8px; font-size:2em; }}
    .hero p{{ margin:0; color:#a0a0b0; }}
    .container{{ max-width:1100px; margin:32px auto; padding:0 24px; }}
    .card{{ background:#fff; border-radius:8px; padding:24px; margin-bottom:24px;
            box-shadow:0 1px 4px rgba(0,0,0,.08); }}
    .card h2{{ margin-top:0; color:#1a1a2e; border-bottom:2px solid #e94560;
               padding-bottom:8px; }}
    table{{ width:100%; border-collapse:collapse; font-size:.9em; }}
    th{{ background:#f7f8fa; padding:10px 12px; text-align:left; color:#555;
         border-bottom:2px solid #e8eaed; }}
    td{{ padding:9px 12px; border-bottom:1px solid #f0f2f5; }}
    tr:hover td{{ background:#fafbfc; }}
    .badge{{ display:inline-block; padding:2px 9px; border-radius:12px;
             font-size:.78em; font-weight:bold; }}
    .badge.Completed{{ background:#d5f5e3; color:#1e8449; }}
    .badge.Queued{{ background:#fef9e7; color:#b7950b; }}
    .badge.Failed{{ background:#fdedec; color:#c0392b; }}
    .objective{{ background:#1a1a2e; color:#e0e0e0; border-radius:8px;
                 padding:20px 24px; margin-bottom:24px; border-left:4px solid #e94560; }}
    .objective h2{{ color:#e94560; margin-top:0; }}
    footer{{ text-align:center; color:#aaa; font-size:.8em; padding:32px; }}
  </style>
</head>
<body>
<nav>
  <a class="brand" href="/">&#128438; PrintMaster Pro</a>
  <a href="/">Dashboard</a>
  <a href="/jobs">Job History</a>
  <a href="/printers">Printers</a>
</nav>
<div class="hero">
  <h1>Enterprise Print Management</h1>
  <p>PrintMaster Technologies Inc. &mdash; Internal Operations Portal</p>
</div>
<div class="container">
  {% block content %}{% endblock %}
</div>
<footer>PrintMaster Pro v3.4.1 &mdash; &copy; 2024 PrintMaster Technologies Inc. All rights reserved.</footer>
</body>
</html>"""

INDEX_TEMPLATE = BASE_TEMPLATE.replace(
    "{% block content %}{% endblock %}",
    """
  <div class="objective">
    <h2>&#127937; Penetration Test Objective</h2>
    <p>
      A CUPS print server is running on this infrastructure.<br/>
      Your objective is to achieve <strong>Remote Code Execution</strong> on the print server host.<br/>
      Proof of compromise: retrieve the contents of <code>/root/flag.txt</code>.
    </p>
  </div>

  <div class="card">
    <h2>System Overview</h2>
    <table>
      <tr><th>Component</th><th>Version</th><th>Protocol</th><th>Port</th></tr>
      <tr><td>CUPS (cupsd)</td><td>System CUPS</td><td>IPP/TCP</td><td>631</td></tr>
      <tr><td>cups-browsed</td><td>2.0.1</td><td>UDP Browse</td><td>631/udp</td></tr>
      <tr><td>libcupsfilters</td><td>2.1b1</td><td>—</td><td>—</td></tr>
      <tr><td>libppd</td><td>2.1b1</td><td>—</td><td>—</td></tr>
      <tr><td>cups-filters</td><td>2.0.1</td><td>—</td><td>—</td></tr>
    </table>
  </div>

  <div class="card">
    <h2>Recent Print Jobs</h2>
    <table>
      <tr><th>Job ID</th><th>User</th><th>Document</th><th>Pages</th><th>Printer</th><th>Status</th></tr>
      {% for job in jobs[:5] %}
      <tr>
        <td>#{{ job.id }}</td>
        <td>{{ job.user }}</td>
        <td>{{ job.doc }}</td>
        <td>{{ job.pages }}</td>
        <td>{{ job.printer }}</td>
        <td><span class="badge {{ job.status }}">{{ job.status }}</span></td>
      </tr>
      {% endfor %}
    </table>
  </div>
"""
)

JOBS_TEMPLATE = BASE_TEMPLATE.replace(
    "{% block content %}{% endblock %}",
    """
  <div class="card">
    <h2>Full Job History</h2>
    <table>
      <tr><th>Job ID</th><th>User</th><th>Document</th><th>Pages</th><th>Printer</th><th>Status</th></tr>
      {% for job in jobs %}
      <tr>
        <td>#{{ job.id }}</td>
        <td>{{ job.user }}</td>
        <td>{{ job.doc }}</td>
        <td>{{ job.pages }}</td>
        <td>{{ job.printer }}</td>
        <td><span class="badge {{ job.status }}">{{ job.status }}</span></td>
      </tr>
      {% endfor %}
    </table>
  </div>
"""
)

PRINTERS_TEMPLATE = BASE_TEMPLATE.replace(
    "{% block content %}{% endblock %}",
    """
  <div class="card">
    <h2>Registered Printers</h2>
    <table>
      <tr><th>Name</th><th>Location</th><th>Protocol</th><th>Status</th></tr>
      <tr><td>HP-LaserJet-Floor2</td><td>2nd Floor, East Wing</td><td>IPP</td>
          <td><span class="badge Completed">Online</span></td></tr>
      <tr><td>Canon-IR2630-Lobby</td><td>Main Lobby</td><td>IPP</td>
          <td><span class="badge Completed">Online</span></td></tr>
      <tr><td>Xerox-WC7845-Acctg</td><td>Accounting Dept.</td><td>IPP</td>
          <td><span class="badge Queued">Busy</span></td></tr>
    </table>
  </div>
"""
)

@app.route("/")
def index():
    return render_template_string(INDEX_TEMPLATE, jobs=JOB_HISTORY)

@app.route("/jobs")
def jobs():
    return render_template_string(JOBS_TEMPLATE, jobs=JOB_HISTORY)

@app.route("/printers")
def printers():
    return render_template_string(PRINTERS_TEMPLATE)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8888, debug=False)
PYEOF

# ── reset.sh ──────────────────────────────────────────────────────────────
cat > reset.sh << 'EOF'
#!/bin/bash
docker compose down -v
docker compose up --build -d
echo "[+] Lab reset complete."
EOF
chmod +x reset.sh

echo "[+] Lab ready. Run: cd cups_rce_chain_lab && docker compose up --build"