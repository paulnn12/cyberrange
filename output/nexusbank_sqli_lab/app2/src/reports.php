<?php
session_start();
require 'config.php';

if (empty($_SESSION['uid'])) {
    header('Location: index.php');
    exit;
}

$statusFilter = $_GET['status'] ?? 'all';
$rows = [];

// ── Time-Based Blind SQLi sink
// The status parameter is injected directly into the query.
// The page always renders the same table structure — no error, no data exfiltration.
// Timing side-channel (SLEEP / BENCHMARK) is the only oracle.
try {
    if ($statusFilter === 'all') {
        $stmt = $pdo->query("SELECT id, report_name, created_by, DATE(created_at) AS date, status FROM reports ORDER BY created_at DESC");
    } else {
        // VULNERABLE: $statusFilter injected directly — no escaping, no parameterisation
        $sql  = "SELECT id, report_name, created_by, DATE(created_at) AS date, status FROM reports WHERE status = '$statusFilter' ORDER BY created_at DESC";
        $stmt = $pdo->query($sql);
    }
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    // Errors are intentionally suppressed — no information leaked to the client
    $rows = [];
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NexusBank — Report List</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Arial,sans-serif;background:#0f0f1a;color:#d8d8f0;min-height:100vh;display:flex;flex-direction:column}
    header{background:#16162a;padding:16px 40px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #6060ff}
    .logo{font-size:1.4rem;font-weight:700;color:#6060ff}
    nav a{color:#7080a0;text-decoration:none;margin-left:20px;font-size:0.9rem}
    nav a:hover{color:#6060ff}
    .main{flex:1;padding:36px 40px}
    h2{color:#6060ff;margin-bottom:20px}
    .objective{background:#0e0e22;border-left:4px solid #f0a500;padding:10px 14px;margin-bottom:20px;font-size:0.82rem;color:#f0c060;border-radius:4px;max-width:800px}
    .filters{display:flex;gap:10px;margin-bottom:24px;flex-wrap:wrap;align-items:center}
    .filters span{font-size:0.85rem;color:#7080a0}
    .filters a{padding:6px 14px;border:1px solid #2a2a50;border-radius:20px;text-decoration:none;color:#a0a0d0;font-size:0.83rem}
    .filters a.active,.filters a:hover{background:#6060ff;color:#fff;border-color:#6060ff}
    table{width:100%;border-collapse:collapse;background:#16162a;border-radius:8px;overflow:hidden;max-width:900px}
    th{background:#20204a;padding:12px 16px;text-align:left;font-size:0.82rem;color:#9090c0;letter-spacing:.5px}
    td{padding:11px 16px;font-size:0.88rem;border-top:1px solid #1e1e38}
    tr:hover td{background:#1a1a30}
    .badge{display:inline-block;padding:3px 10px;border-radius:10px;font-size:0.75rem;font-weight:600}
    .badge.complete{background:#0d3020;color:#50e090}
    .badge.running{background:#0d2040;color:#50a0ff}
    .badge.pending{background:#302010;color:#e0a040}
    footer{text-align:center;padding:14px;font-size:0.75rem;color:#30305a;border-top:1px solid #2a2a50}
  </style>
</head>
<body>
<header>
  <div class="logo">&#9670; NexusBank Reporting</div>
  <nav>
    <a href="reports.php">Reports</a>
    <a href="logout.php">Sign Out (<?= htmlspecialchars($_SESSION['username']) ?>)</a>
  </nav>
</header>
<div class="main">
  <h2>Report Queue</h2>
  <div class="objective">&#127937; <strong>Objective:</strong> The status filter is injectable. Errors are suppressed and no data is echoed — use <code>IF(condition, SLEEP(N), 0)</code> timing attacks to extract data character by character.</div>
  <div class="filters">
    <span>Filter by status:</span>
    <a href="reports.php?status=all"      class="<?= $statusFilter==='all'     ?'active':'' ?>">All</a>
    <a href="reports.php?status=complete" class="<?= $statusFilter==='complete'?'active':'' ?>">Complete</a>
    <a href="reports.php?status=running"  class="<?= $statusFilter==='running' ?'active':'' ?>">Running</a>
    <a href="reports.php?status=pending"  class="<?= $statusFilter==='pending' ?'active':'' ?>">Pending</a>
  </div>
  <table>
    <thead>
      <tr><th>#</th><th>Report Name</th><th>Created By</th><th>Date</th><th>Status</th></tr>
    </thead>
    <tbody>
    <?php foreach ($rows as $r): ?>
      <tr>
        <td><?= (int)$r['id'] ?></td>
        <td><?= htmlspecialchars($r['report_name']) ?></td>
        <td><?= htmlspecialchars($r['created_by']) ?></td>
        <td><?= htmlspecialchars($r['date']) ?></td>
        <td><span class="badge <?= htmlspecialchars($r['status']) ?>"><?= htmlspecialchars($r['status']) ?></span></td>
      </tr>
    <?php endforeach; ?>
    <?php if (empty($rows)): ?>
      <tr><td colspan="5" style="text-align:center;color:#50507a;padding:24px">No reports match this filter.</td></tr>
    <?php endif; ?>
    </tbody>
  </table>
</div>
<footer>&copy; 2024 NexusBank Financial Services — Internal Use Only.</footer>
</body>
</html>
