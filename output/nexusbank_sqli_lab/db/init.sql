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
