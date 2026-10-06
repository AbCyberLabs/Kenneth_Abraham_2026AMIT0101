-- Portfolio 1: Database Design and Modelling
-- Case study: KPay Wallet, a simulated digital wallet and money transfer platform
-- Database: PostgreSQL 16
--
-- Run with:  psql -U postgres -d kpay -f 01_schema.sql

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS transfers CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- One row per person who owns a wallet.
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    phone         VARCHAR(20)  NOT NULL UNIQUE,
    city          VARCHAR(50)  NOT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- A customer can hold more than one account (for example NGN and USD).
CREATE TABLE accounts (
    account_id    SERIAL PRIMARY KEY,
    customer_id   INT          NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    account_no    CHAR(10)     NOT NULL UNIQUE,
    currency      CHAR(3)      NOT NULL DEFAULT 'NGN' CHECK (currency IN ('NGN','USD')),
    balance       NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    status        VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','FROZEN','CLOSED')),
    opened_at     TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Every money movement between two accounts.
CREATE TABLE transfers (
    transfer_id   BIGSERIAL PRIMARY KEY,
    from_account  INT          NOT NULL REFERENCES accounts(account_id),
    to_account    INT          NOT NULL REFERENCES accounts(account_id),
    amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    status        VARCHAR(10)  NOT NULL DEFAULT 'SUCCESS' CHECK (status IN ('PENDING','SUCCESS','FAILED','REVERSED')),
    narration     VARCHAR(100),
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    CHECK (from_account <> to_account)
);

-- A record of who changed what, kept for auditing.
CREATE TABLE audit_log (
    log_id        BIGSERIAL PRIMARY KEY,
    account_id    INT          NOT NULL REFERENCES accounts(account_id),
    action        VARCHAR(30)  NOT NULL,
    old_balance   NUMERIC(14,2),
    new_balance   NUMERIC(14,2),
    logged_at     TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Show the result so you can screenshot it.
\d customers
\d accounts
\d transfers
\d audit_log
