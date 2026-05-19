<?php
session_start();
require 'config.php';

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'login') {
    $u = $_POST['username'] ?? '';
    $p = $_POST['password'] ?? '';
    // Hardcoded analyst credentials for demo access — students must still find admin secrets via SQLi
    $stmt = $pdo->prepare("SELECT * FROM users WHERE username = ? AND password = MD5(?) AND active = 1");
    $stmt->execute([$u, $p]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row) {
        $_SESSION['uid']      = $row['id'];
        $_SESSION['username'] = $row['username'];
        $_SESSION['role']     = $row['role'];
        header('Location: reports.php');
        exit;
    } else {
        $error = 'Invalid credentials.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NexusBank — Reporting Console</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Arial,sans-serif;background:#0f0f1a;color:#d8d8f0;min-height:100vh;display:flex;flex-direction:column}
    header{background:#16162a;padding:16px 40px;display:flex;align-items:center;gap:14px;border-bottom:2px solid #6060ff}
    .logo{font-size:1.5rem;font-weight:700;color:#6060ff}
    .tagline{font-size:0.82rem;color:#6070a0}
    .container{flex:1;display:flex;align-items:center;justify-content:center;padding:40px}
    .card{background:#16162a;border:1px solid #2a2a50;border-radius:10px;padding:40px;width:100%;max-width:420px}
    h2{color:#6060ff;margin-bottom:8px}
    .objective{background:#0e0e22;border-left:4px solid #f0a500;padding:10px 14px;margin-bottom:22px;font-size:0.82rem;color:#f0c060;border-radius:4px}
    .hint{background:#0e0e22;border-left:4px solid #3090ff;padding:8px 12px;margin-bottom:16px;font-size:0.80rem;color:#7ab0ff;border-radius:4px}
    label{display:block;margin-top:14px;font-size:0.85rem;color:#7080a0}
    input[type=text],input[type=password]{width:100%;padding:10px;margin-top:4px;background:#0f0f1a;border:1px solid #2a2a50;border-radius:5px;color:#d8d8f0;font-size:0.95rem}
    button{margin-top:22px;width:100%;padding:11px;background:#6060ff;border:none;border-radius:5px;color:#fff;font-size:1rem;font-weight:600;cursor:pointer}
    button:hover{background:#4040cc}
    .error{margin-top:12px;color:#ff6060;font-size:0.85rem}
    footer{text-align:center;padding:14px;font-size:0.75rem;color:#30305a;border-top:1px solid #2a2a50}
  </style>
</head>
<body>
<header>
  <div class="logo">&#9670; NexusBank</div>
  <div class="tagline">Internal Reporting Console</div>
</header>
<div class="container">
  <div class="card">
    <h2>Analyst Sign In</h2>
    <div class="objective">&#127937; <strong>Objective:</strong> Use time-based blind SQL injection in the report filter to extract usernames, password hashes, and vault secrets from the database.</div>
    <div class="hint">&#128274; Hint: analyst credentials are available via other NexusBank services.</div>
    <form method="POST">
      <input type="hidden" name="action" value="login">
      <label>Username</label>
      <input type="text" name="username" placeholder="analyst1">
      <label>Password</label>
      <input type="password" name="password" placeholder="••••••••">
      <button type="submit">Access Console</button>
    </form>
    <?php if ($error): ?><div class="error">&#9888; <?= htmlspecialchars($error) ?></div><?php endif; ?>
  </div>
</div>
<footer>&copy; 2024 NexusBank Financial Services — Internal Use Only.</footer>
</body>
</html>
