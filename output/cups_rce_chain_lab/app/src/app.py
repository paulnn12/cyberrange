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
