-- Portfolio 3: Transactions and Concurrency (part B, two sessions)
--
-- You need TWO terminal windows, both connected to the database:
--     psql -U postgres -d kpay
-- Call them Session A and Session B. Run the lines in the order shown.
-- Take a screenshot of both windows at the end of each experiment.
--
-- Always reset first (either session):
--     UPDATE accounts SET balance = 80000 WHERE account_id = 1;

======================================================================
EXPERIMENT 1: Lost update (the problem)
======================================================================
Two people change the same balance at the same time. Each one reads the old
balance, works out the new one in their head, then writes it back.

Session A:  BEGIN;
Session A:  SELECT balance FROM accounts WHERE account_id = 1;        -- sees 80000
Session B:  BEGIN;
Session B:  SELECT balance FROM accounts WHERE account_id = 1;        -- also sees 80000
Session A:  UPDATE accounts SET balance = 80000 - 10000 WHERE account_id = 1;   -- A withdraws 10000
Session A:  COMMIT;
Session B:  UPDATE accounts SET balance = 80000 - 5000  WHERE account_id = 1;   -- B withdraws 5000
Session B:  COMMIT;
Either:     SELECT balance FROM accounts WHERE account_id = 1;
-- Result: 75000. It should be 65000. A's withdrawal was silently lost.

======================================================================
EXPERIMENT 2: Lost update fixed with a row lock (SELECT ... FOR UPDATE)
======================================================================
Reset the balance to 80000 first.

Session A:  BEGIN;
Session A:  SELECT balance FROM accounts WHERE account_id = 1 FOR UPDATE;   -- sees 80000, locks the row
Session B:  BEGIN;
Session B:  SELECT balance FROM accounts WHERE account_id = 1 FOR UPDATE;   -- WAITS here (screenshot this)
Session A:  UPDATE accounts SET balance = 80000 - 10000 WHERE account_id = 1;
Session A:  COMMIT;                                                         -- B now wakes up and sees 70000
Session B:  UPDATE accounts SET balance = 70000 - 5000 WHERE account_id = 1;
Session B:  COMMIT;
Either:     SELECT balance FROM accounts WHERE account_id = 1;
-- Result: 65000. Correct. The lock forced B to wait and read the fresh value.

======================================================================
EXPERIMENT 3: Isolation levels (non-repeatable read)
======================================================================
Reset the balance to 80000 first.

-- Part (a): READ COMMITTED (the PostgreSQL default)
Session A:  BEGIN;
Session A:  SELECT balance FROM accounts WHERE account_id = 1;       -- 80000
Session B:  UPDATE accounts SET balance = 90000 WHERE account_id = 1;   -- auto-commits
Session A:  SELECT balance FROM accounts WHERE account_id = 1;       -- 90000  (same query, different answer)
Session A:  COMMIT;

-- Part (b): REPEATABLE READ
Session A:  BEGIN ISOLATION LEVEL REPEATABLE READ;
Session A:  SELECT balance FROM accounts WHERE account_id = 1;       -- 90000
Session B:  UPDATE accounts SET balance = 95000 WHERE account_id = 1;
Session A:  SELECT balance FROM accounts WHERE account_id = 1;       -- still 90000
Session A:  COMMIT;
Session A:  SELECT balance FROM accounts WHERE account_id = 1;       -- now 95000

======================================================================
EXPERIMENT 4: Deadlock
======================================================================
Each session locks one account, then tries to lock the other one.

Session A:  BEGIN;
Session A:  UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
Session B:  BEGIN;
Session B:  UPDATE accounts SET balance = balance - 100 WHERE account_id = 2;
Session A:  UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;   -- waits for B
Session B:  UPDATE accounts SET balance = balance + 100 WHERE account_id = 1;   -- waits for A: DEADLOCK
-- After about one second PostgreSQL stops one session with
--     ERROR: deadlock detected
-- Then in both sessions:
Session A:  ROLLBACK;
Session B:  ROLLBACK;
-- Prevention: always lock accounts in the same order (smaller id first).
-- The make_transfer function in 01_transactions.sql does exactly that.
