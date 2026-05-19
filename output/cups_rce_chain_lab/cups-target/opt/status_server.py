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
