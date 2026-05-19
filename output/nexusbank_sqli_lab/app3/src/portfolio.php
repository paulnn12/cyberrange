<?php
session_start();
require 'config.php';

if (empty($_SESSION['uid'])) {
    header('Location: index.php');
    exit;
}

$uid     = (int)$_SESSION['uid'];
$profile = null;
$perf    = [];
$sqliOut = null;

// Step 1 — fetch the stored profile (parameterised — safe)
$stmt    = $pdo->prepare("SELECT * FROM trading_profiles WHERE user_id = ?");
$stmt->execute([$uid]);
$profile = $stmt->fetch(PDO::FETCH_ASSOC);

if ($profile) {
    // Step 2 — SECOND-ORDER VULN:
    // The display_name was stored safely, but NOW it is retrieved and
    // interpolated directly into a new SQL query without any escaping.
    // An attacker who registered with a malicious display_name triggers
    // the injection here, not at registration time.
    $displayName = $profile['display_name'];

    // This query is the vulnerable sink — display_name is not escaped
    $sql = "SELECT t.id, t.tx_date, t.description, t.amount, t.tx_type
            FROM transactions t
            JOIN accounts a ON t.account_id = a.id
            JOIN users u ON a.user_id = u.id
            WHERE u.username = (SELECT username FROM users WHERE id = $uid)
              AND u.display_name_cache = '$displayName'
            ORDER BY t.tx_date DESC LIMIT 20";

    // Note: display_name_cache column doesn't exist — the query will always fail
    // for legit users (returning empty result), but the injected payload still
    // executes in the DB engine before the column check.
    // To make the second-order fire and return data, the payload must use
    // UNION SELECT or subqueries that resolve before the column error,
    // e.g.: ' UNION SELECT id,created_at,label,CAST(secret AS DECIMAL),tx_type FROM vault_secrets-- -
    try {
        $stmt2 = $pdo->query($sql);
        $perf  = $stmt2->fetchAll(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        // PDO error message is returned raw — this leaks DB error details
        // which helps the attacker confirm injection and refine the UNION
        $sqliOut = $e->getMessage();
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NexusBank — My Portfolio</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Arial,sans-serif;background:#0b1a10;color:#d0e8d0;min-height:100vh;display:flex;flex-direction:column}
    header{background:#102015;padding:16px 40px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #20c050}
    .logo{font-size:1.4rem;font-weight:700;color:#20c050}
    nav a{color:#508060;text-decoration:none;margin-left:20px;font-size:0.9rem}
    nav a:hover{color:#20c050}
    .main{flex:1;padding:36px 40px}
    h2{color:#20c050;margin-bottom:6px}
    .objective{background:#091510;border-left:4px solid #f0a500;padding:10px 14px;margin-bottom:20px;font-size:0.82rem;color:#f0c060;border-radius:4px;max-width:820px}
    .profile-box{background:#102015;border:1px solid #1a3a20;border-radius:8px;padding:20px 24px;max-width:820px;margin-bottom:26px}
    .profile-box h3{color:#20c050;margin-bottom:10px;font-size:1rem}
    .profile-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px 24px;font-size:0.87rem}
    .profile-grid .k{color:#508060}
    .profile-grid .v{color:#d0e8d0}
    .db-error{background:#200a0a;border:1px solid #a03030;border-radius:6px;padding:14px;margin-bottom:20px;font-size:0.8rem;color:#ff9090;font-family:monospace;max-width:820px;word-break:break-all}
    table{width:100%;max-width:820px;border-collapse:collapse;background:#102015;border-radius:8px;overflow:hidden}
    th{background:#182820;padding:11px 14px;text-align:left;font-size:0.81rem;color:#40a060;letter-spacing:.5px}
    td{padding:10px 14px;font-size:0.86rem;border-top:1px solid #1a3a20}
    tr:hover td{background:#142018}
    .credit{color:#40e080}.debit{color:#e06060}
    footer{text-align:center;padding:14px;font-size:0.75rem;color:#20402a;border-top:1px solid #1a3a20}
  </style>
</head>
<body>
<header>
  <div class="logo">&#9670; NexusBank Trading</div>
  <nav>
    <a href="portfolio.php">Portfolio</a>
    <a href="logout.php">Sign Out (<?= htmlspecialchars($_SESSION['username']) ?>)</a>
  </nav>
</header>
<div class="main">
  <h2>My Portfolio</h2>
  <div class="objective">&#127937; <strong>Objective:</strong> Your stored display name is injected unsafely into a query when this page loads. Craft a UNION-based payload in the display name at registration to extract vault secrets and user credentials.</div>

  <?php if ($profile): ?>
  <div class="profile-box">
    <h3>Trader Profile</h3>
    <div class="profile-grid">
      <span class="k">Display Name</span><span class="v"><?= htmlspecialchars($profile['display_name']) ?></span>
      <span class="k">Risk Level</span><span class="v"><?= htmlspecialchars($profile['risk_level']) ?></span>
      <span class="k">Member Since</span><span class="v"><?= htmlspecialchars($profile['created_at']) ?></span>
      <span class="k">Bio</span><span class="v"><?= htmlspecialchars($profile['bio'] ?? '—') ?></span>
    </div>
  </div>
  <?php endif; ?>

  <?php if ($sqliOut): ?>
  <div class="db-error"><strong>Portfolio data service error:</strong><br><?= htmlspecialchars($sqliOut) ?></div>
  <?php endif; ?>

  <h3 style="color:#20c050;margin-bottom:14px;font-size:1rem">Recent Transactions</h3>
  <table>
    <thead>
      <tr><th>#</th><th>Date</th><th>Description</th><th>Amount</th><th>Type</th></tr>
    </thead>
    <tbody>
    <?php foreach ($perf as $r): ?>
      <tr>
        <td><?= htmlspecialchars($r['id'] ?? '') ?></td>
        <td><?= htmlspecialchars($r['tx_date'] ?? '') ?></td>
        <td><?= htmlspecialchars($r['description'] ?? '') ?></td>
        <td class="<?= (isset($r['amount']) && $r['amount'] > 0) ? 'credit' : 'debit' ?>">
          <?= htmlspecialchars(number_format((float)($r['amount'] ?? 0), 2)) ?>
        </td>
        <td><?= htmlspecialchars($r['tx_type'] ?? '') ?></td>
      </tr>
    <?php endforeach; ?>
    <?php if (empty($perf)): ?>
      <tr><td colspan="5" style="text-align:center;color:#305040;padding:22px">No transaction history available for your profile.</td></tr>
    <?php endif; ?>
    </tbody>
  </table>
</div>
<footer>&copy; 2024 NexusBank Financial Services — Trading Division.</footer>
</body>
</html>
