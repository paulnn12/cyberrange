<?php
session_start();
require 'config.php';

if (empty($_SESSION['uid'])) {
    header('Location: index.php');
    exit;
}

$username   = $_SESSION['username'];
$result     = null;
$found      = null;
$acctNumber = '';

// ── Account lookup — Blind Boolean SQLi
// The query only returns a yes/no signal; no column data is ever rendered.
// The injected condition can change the boolean outcome.
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['account_number'])) {
    $acctNumber = $_POST['account_number'];
    // Vulnerable: raw string interpolation inside WHERE
    $sql = "SELECT id FROM accounts WHERE account_number = '$acctNumber' AND active_flag IS NULL OR account_number = '$acctNumber'";
    // Simpler vulnerable query (this one is what actually runs):
    $sql = "SELECT id FROM accounts WHERE account_number = '$acctNumber'";
    try {
        $stmt = $pdo->query($sql);
        $row  = $stmt->fetch(PDO::FETCH_ASSOC);
        // ONLY a boolean signal is returned to the client — classic blind scenario
        $found = ($row !== false);
    } catch (PDOException $e) {
        $found = false;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NexusBank — Dashboard</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Arial,sans-serif;background:#0a1628;color:#e0e8f0;min-height:100vh;display:flex;flex-direction:column}
    header{background:#102040;padding:16px 40px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #1e90ff}
    header .logo{font-size:1.4rem;font-weight:700;color:#1e90ff}
    header nav a{color:#90aaba;text-decoration:none;margin-left:20px;font-size:0.9rem}
    header nav a:hover{color:#1e90ff}
    .main{flex:1;padding:36px 40px}
    h2{color:#1e90ff;margin-bottom:20px}
    .panel{background:#112035;border:1px solid #1e3a5f;border-radius:8px;padding:28px;max-width:500px}
    .objective{background:#0d2a40;border-left:4px solid #f0a500;padding:10px 14px;margin-bottom:20px;font-size:0.82rem;color:#f0c060;border-radius:4px}
    label{display:block;margin-bottom:6px;font-size:0.85rem;color:#90aaba}
    input[type=text]{width:100%;padding:10px;background:#0a1628;border:1px solid #1e3a5f;border-radius:5px;color:#e0e8f0;font-size:0.95rem}
    button{margin-top:16px;padding:10px 28px;background:#1e90ff;border:none;border-radius:5px;color:#fff;font-weight:600;cursor:pointer}
    button:hover{background:#1670cc}
    .result{margin-top:18px;padding:12px 16px;border-radius:6px;font-size:0.9rem}
    .result.found{background:#0d3020;border:1px solid #20a060;color:#50e090}
    .result.notfound{background:#301010;border:1px solid #a03030;color:#e06060}
    footer{text-align:center;padding:14px;font-size:0.75rem;color:#3a5060;border-top:1px solid #1e3a5f}
  </style>
</head>
<body>
<header>
  <div class="logo">&#9670; NexusBank</div>
  <nav>
    <a href="dashboard.php">Dashboard</a>
    <a href="logout.php">Sign Out (<?= htmlspecialchars($username) ?>)</a>
  </nav>
</header>
<div class="main">
  <h2>Account Lookup</h2>
  <div class="panel">
    <div class="objective">&#127937; <strong>Objective:</strong> Use blind SQL injection to enumerate and extract all usernames, passwords, and vault secrets from the database. The response only tells you <em>found</em> or <em>not found</em>.</div>
    <form method="POST">
      <label for="an">Account Number</label>
      <input type="text" id="an" name="account_number" value="<?= htmlspecialchars($acctNumber) ?>" placeholder="e.g. NX-0001-CHK">
      <button type="submit">Look Up</button>
    </form>
    <?php if ($found === true): ?>
      <div class="result found">&#10003; Account found in our records.</div>
    <?php elseif ($found === false): ?>
      <div class="result notfound">&#10007; No account matched that number.</div>
    <?php endif; ?>
  </div>
</div>
<footer>&copy; 2024 NexusBank Financial Services. All rights reserved.</footer>
</body>
</html>
