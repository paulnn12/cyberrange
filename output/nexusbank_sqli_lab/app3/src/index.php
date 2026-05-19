<?php
session_start();
require 'config.php';

$error = '';
$tab   = $_GET['tab'] ?? 'login';

// ── Registration
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'register') {
    $u    = trim($_POST['reg_username'] ?? '');
    $p    = trim($_POST['reg_password'] ?? '');
    $dn   = trim($_POST['display_name'] ?? '');
    $bio  = trim($_POST['bio'] ?? '');

    if ($u && $p && $dn) {
        try {
            // Registration is properly parameterised — the display_name is stored safely
            $stmt = $pdo->prepare("INSERT INTO users (username, password, email, role) VALUES (?, MD5(?), ?, 'customer')");
            $stmt->execute([$u, $p, $u . '@nexusbank-trading.com']);
            $uid = $pdo->lastInsertId();

            // display_name stored safely with prepared statement
            $stmt2 = $pdo->prepare("INSERT INTO trading_profiles (user_id, display_name, risk_level, bio) VALUES (?, ?, 'medium', ?)");
            $stmt2->execute([$uid, $dn, $bio]);

            $tab   = 'login';
            $error = '✓ Account created. Please sign in.';
        } catch (PDOException $e) {
            $error = 'Username already taken or DB error.';
        }
    } else {
        $error = 'All fields are required.';
    }
}

// ── Login
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'login') {
    $u = $_POST['username'] ?? '';
    $p = $_POST['password'] ?? ''; 
    $stmt = $pdo->prepare("SELECT * FROM users WHERE username = ? AND password = MD5(?) AND active = 1");
    $stmt->execute([$u, $p]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row) {
        $_SESSION['uid']      = $row['id'];
        $_SESSION['username'] = $row['username'];
        header('Location: portfolio.php');
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
  <title>NexusBank — Trading Platform</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Arial,sans-serif;background:#0b1a10;color:#d0e8d0;min-height:100vh;display:flex;flex-direction:column}
    header{background:#102015;padding:16px 40px;display:flex;align-items:center;gap:14px;border-bottom:2px solid #20c050}
    .logo{font-size:1.5rem;font-weight:700;color:#20c050}
    .tagline{font-size:0.82rem;color:#508060}
    .container{flex:1;display:flex;align-items:center;justify-content:center;padding:40px}
    .card{background:#102015;border:1px solid #1a3a20;border-radius:10px;padding:36px;width:100%;max-width:480px}
    .tabs{display:flex;gap:0;margin-bottom:24px;border-bottom:2px solid #1a3a20}
    .tabs a{padding:9px 22px;text-decoration:none;color:#508060;font-size:0.9rem;border-bottom:3px solid transparent;margin-bottom:-2px}
    .tabs a.active{color:#20c050;border-bottom-color:#20c050;font-weight:600}
    h2{color:#20c050;margin-bottom:8px}
    .objective{background:#091510;border-left:4px solid #f0a500;padding:10px 14px;margin-bottom:20px;font-size:0.82rem;color:#f0c060;border-radius:4px}
    label{display:block;margin-top:12px;font-size:0.85rem;color:#508060}
    input[type=text],input[type=password],textarea{width:100%;padding:9px;margin-top:4px;background:#0b1a10;border:1px solid #1a3a20;border-radius:5px;color:#d0e8d0;font-size:0.93rem}
    textarea{height:70px;resize:vertical}
    button{margin-top:20px;width:100%;padding:10px;background:#20c050;border:none;border-radius:5px;color:#0b1a10;font-size:1rem;font-weight:700;cursor:pointer}
    button:hover{background:#18a040}
    .msg{margin-top:10px;font-size:0.85rem;color:#40d070}
    .error{margin-top:10px;font-size:0.85rem;color:#ff7070}
    footer{text-align:center;padding:14px;font-size:0.75rem;color:#20402a;border-top:1px solid #1a3a20}
  </style>
</head>
<body>
<header>
  <div class="logo">&#9670; NexusBank</div>
  <div class="tagline">Trading Platform — Market Execution</div>
</header>
<div class="container">
  <div class="card">
    <div class="tabs">
      <a href="?tab=login"    class="<?= $tab==='login'   ?'active':'' ?>">Sign In</a>
      <a href="?tab=register" class="<?= $tab==='register'?'active':'' ?>">Register</a>
    </div>
    <?php if ($tab === 'login'): ?>
    <h2>Trader Login</h2>
    <div class="objective">&#127937; <strong>Objective:</strong> Exploit second-order SQL injection. Register an account with a crafted <em>Display Name</em>, then visit your portfolio — the stored name is later injected unsafely into a query.</div>
    <form method="POST">
      <input type="hidden" name="action" value="login">
      <label>Username</label>
      <input type="text" name="username" placeholder="e.g. jsmith">
      <label>Password</label>
      <input type="password" name="password" placeholder="••••••••">
      <button>Sign In</button>
    </form>
    <?php if ($error): ?>
      <div class="<?= str_starts_with($error,'✓')?'msg':'error' ?>"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>
    <?php else: ?>
    <h2>Create Trader Account</h2>
    <div class="objective">&#127937; <strong>Objective:</strong> The <em>Display Name</em> field is the injection vector. It is stored safely on registration but reused <em>without escaping</em> in a later query. Craft your payload here.</div>
    <form method="POST">
      <input type="hidden" name="action" value="register">
      <label>Username</label>
      <input type="text" name="reg_username" placeholder="Choose a username">
      <label>Password</label>
      <input type="password" name="reg_password" placeholder="Choose a password">
      <label>Display Name <small style="color:#806040">(shown on your portfolio)</small></label>
      <input type="text" name="display_name" placeholder="e.g. John S.">
      <label>Bio <small style="color:#508060">(optional)</small></label>
      <textarea name="bio" placeholder="Tell other traders about your strategy..."></textarea>
      <button>Create Account</button>
    </form>
    <?php if ($error): ?>
      <div class="<?= str_starts_with($error,'✓')?'msg':'error' ?>"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>
    <?php endif; ?>
  </div>
</div>
<footer>&copy; 2024 NexusBank Financial Services — Trading Division.</footer>
</body>
</html>
