-- Portfolio 3: Transactions and Concurrency (part A, single session)
-- Shows COMMIT, ROLLBACK, a safe transfer function, and a trigger audit log.
--
-- Run with:  psql -U postgres -d kpay -f 01_transactions.sql
-- Run each block yourself in psql if you want clean screenshots.

----------------------------------------------------------------------
-- 0. Two test accounts with known balances
----------------------------------------------------------------------
UPDATE accounts SET balance = 100000 WHERE account_id = 1;
UPDATE accounts SET balance = 50000  WHERE account_id = 2;
SELECT account_id, balance FROM accounts WHERE account_id IN (1,2) ORDER BY account_id;

----------------------------------------------------------------------
-- 1. COMMIT: a transfer of 20,000 that works
----------------------------------------------------------------------
BEGIN;
UPDATE accounts SET balance = balance - 20000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 20000 WHERE account_id = 2;
INSERT INTO transfers (from_account, to_account, amount, status, narration)
VALUES (1, 2, 20000, 'SUCCESS', 'Rent contribution');
COMMIT;

SELECT account_id, balance FROM accounts WHERE account_id IN (1,2) ORDER BY account_id;
-- Expected: account 1 = 80000, account 2 = 70000

----------------------------------------------------------------------
-- 2. ROLLBACK: the user changes their mind halfway
----------------------------------------------------------------------
BEGIN;
UPDATE accounts SET balance = balance - 5000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 5000 WHERE account_id = 2;
-- Look inside the transaction: the changes are visible here only.
SELECT account_id, balance FROM accounts WHERE account_id IN (1,2) ORDER BY account_id;
ROLLBACK;

-- After rollback the balances are back to what they were.
SELECT account_id, balance FROM accounts WHERE account_id IN (1,2) ORDER BY account_id;

----------------------------------------------------------------------
-- 3. Atomicity in action: the second step fails, so the first is undone
----------------------------------------------------------------------
-- The CHECK (balance >= 0) rule blocks overdrawing. The whole transaction fails
-- and nothing is saved.
BEGIN;
UPDATE accounts SET balance = balance + 999999 WHERE account_id = 2;   -- step 1 works
UPDATE accounts SET balance = balance - 999999 WHERE account_id = 1;   -- step 2 breaks the rule
COMMIT;   -- PostgreSQL turns this into a ROLLBACK because the transaction is aborted

SELECT account_id, balance FROM accounts WHERE account_id IN (1,2) ORDER BY account_id;
-- Account 2 did NOT keep the extra 999999.

----------------------------------------------------------------------
-- 4. A reusable, safe transfer function
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION make_transfer(p_from INT, p_to INT, p_amount NUMERIC, p_note TEXT)
RETURNS TEXT AS $$
DECLARE
    from_bal NUMERIC;
BEGIN
    IF p_from = p_to THEN
        RETURN 'FAILED: cannot send to the same account';
    END IF;

    -- Lock both rows in a fixed order (smaller id first) to avoid deadlocks.
    PERFORM 1 FROM accounts WHERE account_id IN (p_from, p_to) ORDER BY account_id FOR UPDATE;

    SELECT balance INTO from_bal FROM accounts WHERE account_id = p_from;

    IF from_bal < p_amount THEN
        INSERT INTO transfers (from_account, to_account, amount, status, narration)
        VALUES (p_from, p_to, p_amount, 'FAILED', p_note);
        RETURN 'FAILED: insufficient funds';
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to;
    INSERT INTO transfers (from_account, to_account, amount, status, narration)
    VALUES (p_from, p_to, p_amount, 'SUCCESS', p_note);

    RETURN 'SUCCESS';
END;
$$ LANGUAGE plpgsql;

SELECT make_transfer(1, 2, 1000,   'Test good transfer');
SELECT make_transfer(1, 2, 900000, 'Test too large');
SELECT account_id, balance FROM accounts WHERE account_id IN (1,2) ORDER BY account_id;

----------------------------------------------------------------------
-- 5. Trigger: every balance change is written to audit_log automatically
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_balance_change() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.balance <> OLD.balance THEN
        INSERT INTO audit_log (account_id, action, old_balance, new_balance)
        VALUES (NEW.account_id, 'BALANCE_CHANGE', OLD.balance, NEW.balance);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_balance ON accounts;
CREATE TRIGGER trg_audit_balance
AFTER UPDATE ON accounts
FOR EACH ROW EXECUTE FUNCTION log_balance_change();

SELECT make_transfer(2, 1, 500, 'Trigger test');
SELECT * FROM audit_log ORDER BY log_id DESC LIMIT 4;
