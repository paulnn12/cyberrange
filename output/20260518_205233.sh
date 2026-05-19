#!/bin/bash
# Lab: Three advanced SQL Injection scenarios
# Company: NexusBank Financial Services
# App 1 (port 8081): NexusBank Customer Portal — Blind Boolean-Based SQLi in account lookup
# App 2 (port 8082): NexusBank Admin Reporting — Time-Based Blind SQLi in report filters
# App 3 (port 8083): NexusBank Trading Platform — Second-Order SQLi via user profile update
# Stack: PHP 8.1 + Apache + MySQL 8.0.36
# Objective (visible in each app): "Find credentials and sensitive data hidden in the database"

set -e

LAB_DIR="nexusbank_sqli_lab"
mkdir -p "$LAB_DIR"/{app1/src,app2/src,app3/src,db}
cd "$LAB_DIR"

# ─────────────────────────────────────────────
# docker-compose.yml
# ─────────────────────────────────────────────
cat > docker-compose.yml << 'EOF'
services:

  db:
    image: mysql:8.0.36
    container_name: nexusbank_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: n3xus_r00t_2024
      MYSQL_DATABASE: nexusbank
      MYSQL_USER: nexus_app
      MYSQL_PASSWORD: nexus_app_p@ss
    volumes:
      - db_data:/var/lib/mysql
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - lab_net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-u", "root", "-pn3xus_r00t_2024"]
      interval: 5s
      timeout: 4s
      retries: 15

  app1:
    build: ./app1
    image: nexusbank-portal:1.0
    container_name: nexusbank_portal
    restart: unless-stopped
    ports:
      - "8081:80"
    depends_on:
      db:
        condition: service_healthy
    environment:
      DB_HOST: db
      DB_USER: nexus_app
      DB_PASS: nexus_app_p@ss
      DB_NAME: nexusbank
    networks:
      - lab_net

  app2:
    build: ./app2
    image: nexusbank-reporting:1.0
    container_name: nexusbank_reporting
    restart: unless-stopped
    ports:
      - "8082:80"
    depends_on:
      db:
        condition: service_healthy
    environment:
      DB_HOST: db
      DB_USER: nexus_app
      DB_PASS: nexus_app_p@ss
      DB_NAME: nexusbank
    networks:
      - lab_net

  app3:
    build: ./app3
    image: nexusbank-trading:1.0
    container_name: nexusbank_trading
    restart: unless-stopped
    ports:
      - "8083:80"
    depends_on:
      db:
        condition: service_healthy
    environment:
      DB_HOST: db
      DB_USER: nexus_app
      DB_PASS: nexus_app_p@ss
      DB_NAME: nexusbank
    networks:
      - lab_net

networks:
  lab_net:
    driver: bridge

volumes:
  db_data:
EOF

# ─────────────────────────────────────────────
# DATABASE — init.sql
# ─────────────────────────────────────────────
cat > db/init.sql << 'EOF'
USE nexusbank;

-- ─── Users table (shared across apps) ───
CREATE TABLE users (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(80)  NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  email    VARCHAR(120) NOT NULL,
  role     VARCHAR(20)  NOT NULL DEFAULT 'customer',
  active   TINYINT      NOT NULL DEFAULT 1
);

INSERT INTO users (username, password, email, role) VALUES
  ('jsmith',    MD5('Spring2024!'),      'j.smith@nexusbank.com',      'customer'),
  ('mgarcia',   MD5('Tequila#88'),       'm.garcia@nexusbank.com',     'customer'),
  ('lwang',     MD5('Dragon$Fire9'),     'l.wang@nexusbank.com',       'customer'),
  ('aproctor',  MD5('Anchor!7'),         'a.proctor@nexusbank.com',    'customer'),
  ('tnguyen',   MD5('Saigon2k24'),       't.nguyen@nexusbank.com',     'customer'),
  ('rkelley',   MD5('Redwood#11'),       'r.kelley@nexusbank.com',     'customer'),
  ('sfoster',   MD5('Sunflower!5'),      's.foster@nexusbank.com',     'customer'),
  ('dmiller',   MD5('Denver@2023'),      'd.miller@nexusbank.com',     'customer'),
  ('hchang',    MD5('H0ngKong!'),        'h.chang@nexusbank.com',      'customer'),
  ('bwhite',    MD5('BlizzardX#'),       'b.white@nexusbank.com',      'customer'),
  ('analyst1',  MD5('Repo#rtPass99'),    'analyst1@nexusbank.com',     'analyst'),
  ('analyst2',  MD5('Qu3ryM4ster!'),     'analyst2@nexusbank.com',     'analyst'),
  ('superadmin',MD5('Nx$Bank_Adm1n!'),  'superadmin@nexusbank.com',   'admin');

-- ─── Accounts ───
CREATE TABLE accounts (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  user_id        INT NOT NULL,
  account_number VARCHAR(20) NOT NULL UNIQUE,
  account_type   VARCHAR(30) NOT NULL,
  balance        DECIMAL(15,2) NOT NULL,
  currency       VARCHAR(3)  NOT NULL DEFAULT 'USD',
  opened_date    DATE NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO accounts (user_id, account_number, account_type, balance, currency, opened_date) VALUES
  (1,  'NX-0001-CHK', 'Checking',   12453.77,  'USD', '2019-03-14'),
  (2,  'NX-0002-SAV', 'Savings',    88020.50,  'USD', '2020-07-01'),
  (3,  'NX-0003-CHK', 'Checking',    4321.10,  'USD', '2021-01-20'),
  (4,  'NX-0004-INV', 'Investment', 245000.00, 'USD', '2018-11-05'),
  (5,  'NX-0005-SAV', 'Savings',    19875.30,  'USD', '2022-06-15'),
  (6,  'NX-0006-CHK', 'Checking',    3240.60,  'USD', '2023-02-28'),
  (7,  'NX-0007-INV', 'Investment', 512300.00, 'USD', '2017-09-09'),
  (8,  'NX-0008-SAV', 'Savings',    67890.00,  'USD', '2020-12-01'),
  (9,  'NX-0009-CHK', 'Checking',    9105.45,  'USD', '2021-08-19'),
  (10, 'NX-0010-INV', 'Investment', 134000.75, 'USD', '2019-05-30');

-- ─── Transactions ───
CREATE TABLE transactions (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  account_id  INT NOT NULL,
  tx_date     DATETIME NOT NULL,
  description VARCHAR(200) NOT NULL,
  amount      DECIMAL(12,2) NOT NULL,
  tx_type     VARCHAR(10) NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(id)
);

INSERT INTO transactions (account_id, tx_date, description, amount, tx_type) VALUES
  (1, '2024-04-01 09:15:00', 'Direct Deposit - Payroll',       3200.00, 'CREDIT'),
  (1, '2024-04-03 14:22:00', 'Amazon Purchase',                -129.99, 'DEBIT'),
  (2, '2024-04-02 10:00:00', 'Interest Payment',                 88.50, 'CREDIT'),
  (3, '2024-04-04 08:45:00', 'ATM Withdrawal',                 -200.00, 'DEBIT'),
  (4, '2024-04-01 11:00:00', 'Dividend - NVDA',                5400.00, 'CREDIT'),
  (5, '2024-04-05 16:33:00', 'Transfer from Checking',          500.00, 'CREDIT'),
  (6, '2024-04-06 07:20:00', 'Utility Bill - Gas',              -87.40, 'DEBIT'),
  (7, '2024-04-02 13:10:00', 'Dividend - AAPL',               12000.00, 'CREDIT'),
  (8, '2024-04-07 09:55:00', 'Mortgage Payment',             -1800.00,  'DEBIT'),
  (9, '2024-04-03 17:45:00', 'Online Transfer',                -350.00, 'DEBIT');

-- ─── Reports (used by app2) ───
CREATE TABLE reports (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  report_name VARCHAR(100) NOT NULL,
  created_by  VARCHAR(80)  NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status      VARCHAR(20)  NOT NULL DEFAULT 'pending',
  parameters  TEXT
);

INSERT INTO reports (report_name, created_by, created_at, status, parameters) VALUES
  ('Q1 Revenue Summary',        'analyst1',   '2024-01-31 08:00:00', 'complete', 'year=2024&quarter=1'),
  ('Q4 2023 Loss Analysis',     'analyst2',   '2024-01-15 09:30:00', 'complete', 'year=2023&quarter=4'),
  ('March Transactions Audit',  'analyst1',   '2024-04-01 11:00:00', 'running',  'month=3&year=2024'),
  ('High-Value Account Review', 'superadmin', '2024-03-20 14:00:00', 'complete', 'threshold=100000'),
  ('Fraud Detection Sweep',     'analyst2',   '2024-04-05 07:45:00', 'pending',  'type=anomaly'),
  ('Annual Compliance Export',  'superadmin', '2024-02-28 10:00:00', 'complete', 'year=2023'),
  ('Investment Portfolio Perf', 'analyst1',   '2024-04-10 13:20:00', 'running',  'account_type=Investment'),
  ('Dormant Account Scan',      'analyst2',   '2024-03-01 08:00:00', 'complete', 'inactive_days=180'),
  ('Currency Exposure Report',  'analyst1',   '2024-04-08 15:00:00', 'pending',  'currency=USD'),
  ('AML Suspicious Activity',   'superadmin', '2024-04-09 06:30:00', 'running',  'flag=suspicious');

-- ─── Trading profiles (used by app3 — stores username in a profile column used later in a query) ───
CREATE TABLE trading_profiles (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      INT NOT NULL UNIQUE,
  display_name VARCHAR(120) NOT NULL,
  risk_level   VARCHAR(20)  NOT NULL DEFAULT 'medium',
  bio          TEXT,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO trading_profiles (user_id, display_name, risk_level, bio) VALUES
  (1,  'John S.',     'medium', 'Diversified portfolio, long-term investor.'),
  (2,  'Maria G.',    'low',    'Conservative saver. No day trading.'),
  (3,  'Lin W.',      'high',   'Crypto enthusiast. High volatility tolerance.'),
  (4,  'Andrew P.',   'medium', 'Index funds focus.'),
  (5,  'Tuan N.',     'low',    'Bonds and blue chips only.'),
  (6,  'Ryan K.',     'medium', 'Balanced growth strategy.'),
  (7,  'Sara F.',     'high',   'Commodities and emerging markets.'),
  (8,  'Derek M.',    'medium', 'Retirement planning phase.'),
  (9,  'Hui C.',      'low',    'Capital preservation priority.'),
  (10, 'Ben W.',      'high',   'Active trader, options and futures.');

-- ─── Secret vault (the prize) ───
CREATE TABLE vault_secrets (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  label   VARCHAR(100) NOT NULL,
  secret  VARCHAR(255) NOT NULL
);

INSERT INTO vault_secrets (label, secret) VALUES
  ('FLAG',               'FLAG{nx_sql_m4st3r_2024_pwn3d}'),
  ('AWS_ACCESS_KEY',     'AKIA4NEXUSBANK2024XYZ'),
  ('AWS_SECRET',         'wJalrXUtnFEMI/K7MDENG/bPxRfiCYNEXUSKEY'),
  ('INTERNAL_API_KEY',   'nx-internal-v2-8f3a91bc7e2d4051af'),
  ('DB_ROOT_PASSWORD',   'n3xus_r00t_2024');
EOF

# ─────────────────────────────────────────────
# APP 1 — Blind Boolean-Based SQLi
# Customer portal: account lookup by account number
# The WHERE clause on account_number is injectable but returns
# only a binary signal (found / not found) — no data is echoed back.
# The app also has a login form vulnerable to classic auth bypass.
# ─────────────────────────────────────────────
cat > app1/Dockerfile << 'EOF'
FROM php:8.1-apache
RUN docker-php-ext-install pdo pdo_mysql
WORKDIR /var/www/html
COPY src/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html
EXPOSE 80
EOF

cat > app1/src/config.php << 'EOF'
<?php
$dsn  = 'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME') . ';charset=utf8mb4';
$user = getenv('DB_USER');
$pass = getenv('DB_PASS');
try {
    $pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
    http_response_code(503);
    exit('Database unavailable. Please try again later.');
}
EOF

cat > app1/src/index.php << 'EOF'
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
EOF

cat > app1/src/dashboard.php << 'EOF'
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
EOF

cat > app1/src/logout.php << 'EOF'
<?php
session_start();
session_destroy();
header('Location: index.php');
exit;
EOF

# ─────────────────────────────────────────────
# APP 2 — Time-Based Blind SQLi
# Admin Reporting console: filter reports by status
# The status filter is injectable; the app always returns the same HTML
# table structure regardless of the payload — only timing reveals truth.
# ─────────────────────────────────────────────
cat > app2/Dockerfile << 'EOF'
FROM php:8.1-apache
RUN docker-php-ext-install pdo pdo_mysql
WORKDIR /var/www/html
COPY src/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html
EXPOSE 80
EOF

cat > app2/src/config.php << 'EOF'
<?php
$dsn  = 'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME') . ';charset=utf8mb4';
$user = getenv('DB_USER');
$pass = getenv('DB_PASS');
try {
    $pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
    http_response_code(503);
    exit('Database unavailable.');
}
EOF

cat > app2/src/index.php << 'EOF'
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
EOF

cat > app2/src/reports.php << 'EOF'
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
EOF

cat > app2/src/logout.php << 'EOF'
<?php
session_start();
session_destroy();
header('Location: index.php');
exit;
EOF

# ─────────────────────────────────────────────
# APP 3 — Second-Order SQLi
# Trading platform: user registers, sets a display_name that is stored safely.
# Later, when the user views their "portfolio performance" page,
# the app fetches their stored display_name and injects it RAW into
# a second query — the classic second-order pattern.
# ─────────────────────────────────────────────
cat > app3/Dockerfile << 'EOF'
FROM php:8.1-apache
RUN docker-php-ext-install pdo pdo_mysql
WORKDIR /var/www/html
COPY src/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html
EXPOSE 80
EOF

cat > app3/src/config.php << 'EOF'
<?php
$dsn  = 'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME') . ';charset=utf8mb4';
$user = getenv('DB_USER');
$pass = getenv('DB_PASS');
try {
    $pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
    http_response_code(503);
    exit('Database unavailable.');
}
EOF

cat > app3/src/index.php << 'EOF'
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
EOF

cat > app3/src/portfolio.php << 'EOF'
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
EOF

cat > app3/src/logout.php << 'EOF'
<?php
session_start();
session_destroy();
header('Location: index.php');
exit;
EOF

# ─────────────────────────────────────────────
# reset.sh
# ─────────────────────────────────────────────
cat > reset.sh << 'EOF'
#!/bin/bash
docker compose down -v
docker compose up --build -d
echo "[+] Lab reset complete."
EOF
chmod +x reset.sh

echo "[+] Lab ready. Run: cd nexusbank_sqli_lab && docker compose up --build"