<?php
session_start();
require 'config.php';

$error   = '';
$success = '';

// ── Login (intentionally vulnerable to auth-bypass via classic SQLi in username field)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'login') {
    $u = $_POST['username'] ?? '';
    $p = $_POST['password'] ?? '';

    // WARNING: raw interpolation — vulnerable to authentication bypass
    $sql = "SELECT * FROM users WHERE username = '$u' AND password = MD5('$p') AND active = 1";
    try {
        $stmt = $pdo->query($sql);
        $row  = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($row) {
            $_SESSION['uid']      = $row['id'];
            $_SESSION['username'] = $row['username'];
            $_SESSION['role']     = $row['role'];
            header('Location: dashboard.php');
            exit;
        } else {
            $error = 'Invalid credentials.';
        }
    } catch (PDOException $e) {
        $error = 'Authentication error.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NexusBank — Customer Portal</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Arial,sans-serif;background:#0a1628;color:#e0e8f0;min-height:100vh;display:flex;flex-direction:column}
    header{background:#102040;padding:18px 40px;display:flex;align-items:center;gap:16px;border-bottom:2px solid #1e90ff}
    header .logo{font-size:1.6rem;font-weight:700;color:#1e90ff;letter-spacing:1px}
    header .tagline{font-size:0.85rem;color:#7090a0}
    .container{flex:1;display:flex;align-items:center;justify-content:center;padding:40px}
    .card{background:#112035;border:1px solid #1e3a5f;border-radius:10px;padding:40px;width:100%;max-width:420px;box-shadow:0 8px 32px rgba(0,0,0,.5)}
    h2{color:#1e90ff;margin-bottom:6px;font-size:1.3rem}
    .objective{background:#0d2a40;border-left:4px solid #f0a500;padding:10px 14px;margin-bottom:22px;font-size:0.82rem;color:#f0c060;border-radius:4px}
    label{display:block;margin-top:14px;font-size:0.85rem;color:#90aaba}
    input[type=text],input[type=password]{width:100%;padding:10px;margin-top:4px;background:#0a1628;border:1px solid #1e3a5f;border-radius:5px;color:#e0e8f0;font-size:0.95rem}
    button{margin-top:22px;width:100%;padding:11px;background:#1e90ff;border:none;border-radius:5px;color:#fff;font-size:1rem;font-weight:600;cursor:pointer}
    button:hover{background:#1670cc}
    .error{margin-top:12px;color:#ff6060;font-size:0.85rem}
    footer{text-align:center;padding:16px;font-size:0.75rem;color:#3a5060;border-top:1px solid #1e3a5f}
  </style>
</head>
<body>
<header>
  <div class="logo">&#9670; NexusBank</div>
  <div class="tagline">Customer Portal — Secure Online Banking</div>
</header>
<div class="container">
  <div class="card">
    <h2>Sign In</h2>
    <div class="objective">&#127937; <strong>Objective:</strong> Bypass authentication and extract credentials &amp; sensitive secrets from the database.</div>
    <form method="POST">
      <input type="hidden" name="action" value="login">
      <label>Username</label>
      <input type="text" name="username" autocomplete="off" placeholder="e.g. jsmith">
      <label>Password</label>
      <input type="password" name="password" placeholder="••••••••">
      <button type="submit">Log In</button>
    </form>
    <?php if ($error): ?><div class="error">&#9888; <?= htmlspecialchars($error) ?></div><?php endif; ?>
  </div>
</div>
<footer>&copy; 2024 NexusBank Financial Services. All rights reserved.</footer>
</body>
</html>
