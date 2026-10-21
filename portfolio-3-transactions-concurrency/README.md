# Portfolio 3: Transactions and Concurrency

## Files

| File | What it does |
|---|---|
| `01_transactions.sql` | COMMIT, ROLLBACK, a failed transaction, a safe transfer function and an audit trigger |
| `02_concurrency_experiments.md` | Four experiments using two terminal windows |

## Part A: run the script

```
psql -U postgres -d kpay -f 01_transactions.sql
```

What it shows:

1. A transfer that is committed. The balances change and stay changed.
2. A transfer that is rolled back. The balances return to what they were.
3. A transaction where the second step breaks the `balance >= 0` rule. PostgreSQL cancels the whole thing, so the first step is undone too. This is atomicity.
4. `make_transfer()`, a function that locks both accounts in a fixed order, checks funds, then moves the money.
5. A trigger that writes every balance change into `audit_log` automatically.

## Part B: two terminals

Open two terminal windows, both running `psql -U postgres -d kpay`. Follow `02_concurrency_experiments.md`.

| Experiment | Problem shown | Fix shown |
|---|---|---|
| 1 | Lost update: final balance 75000 instead of 65000 | none yet |
| 2 | none | `SELECT ... FOR UPDATE` row lock gives the correct 65000 |
| 3 | Non repeatable read under READ COMMITTED | REPEATABLE READ gives a stable view |
| 4 | Deadlock, PostgreSQL stops one session | Lock in a fixed order |
## Results from my own run

Run on 12 October 2026 in SQL Shell (psql), PostgreSQL 16.15 on Windows.
Part A was run one block at a time so that each screenshot is clean.

| Part A step | Result |
|---|---|
| COMMIT of 20000 | Balances 80000.00 and 70000.00, and they stayed |
| ROLLBACK of 5000 | Inside 75000.00 and 75000.00, after 80000.00 and 70000.00 |
| Atomicity test | Step 2 broke the balance rule, all undone, nothing saved |
| make_transfer 1000 | SUCCESS, balances 79000.00 and 71000.00 |
| make_transfer 900000 | FAILED: insufficient funds, balances unchanged |
| Audit trigger | 2 audit_log rows: 71000.00 to 70500.00, 79000.00 to 79500.00 |

| Part B experiment | Result |
|---|---|
| 1 Lost update | Both read 80000.00. Final balance 75000.00, not 65000.00 |
| 2 FOR UPDATE | B waited, then read 70000.00. Final balance 65000.00 |
| 3a READ COMMITTED | 80000.00, then 90000.00, in the same transaction |
| 3b REPEATABLE READ | 90000.00 both times, then 95000.00 after COMMIT |
| 4 Deadlock | B got ERROR: deadlock detected. Balances after: 95000.00, 70500.00 |

## Screenshots

All files are in the screenshots folder.

| File | What it shows |
|---|---|
| `p3_01_start_balances.png` | Accounts 1 and 2 set to 100000.00 and 50000.00 |
| `p3_02_commit.png` | Committed transfer of 20000, balances 80000.00 and 70000.00 |
| `p3_03_rollback.png` | Rolled back transfer of 5000, balances back to normal |
| `p3_04_atomicity.png` | Step 2 breaks the balance check, whole transaction undone |
| `p3_05_make_transfer.png` | make_transfer: 1000 succeeds, 900000 is refused |
| `p3_06_audit_trigger.png` | The trigger wrote 2 rows to audit_log |
| `p3_07_lost_update.png` | Experiment 1: final balance 75000.00, not 65000.00 |
| `p3_08_for_update_wait.png` | Experiment 2: Session B waiting for the row lock |
| `p3_09_for_update_result.png` | Experiment 2: B read 70000.00, final 65000.00 |
| `p3_10_read_committed.png` | Experiment 3a: 80000.00, then 90000.00 |
| `p3_11_repeatable_read.png` | Experiment 3b: 90000.00 twice, then 95000.00 |
| `p3_12_deadlock.png` | Experiment 4: ERROR: deadlock detected in Session B |
| `p3_13_after_deadlock.png` | Experiment 4: after ROLLBACK, 95000.00 and 70500.00 |

## ACID in one line each (to use in your write up)

- **Atomicity:** all steps of a transaction happen or none do.
- **Consistency:** the rules (constraints) are never broken by a committed transaction.
- **Isolation:** transactions running together do not see each other's half finished work, to a degree set by the isolation level.
- **Durability:** once committed, the data survives a crash.

## Analysis

### 1. Why did the lost update happen in Experiment 1?

### 2. What exactly did FOR UPDATE make Session B do?

### 3. What did the isolation level experiment show?

### 4. What happened in the deadlock, and why does a fixed lock order prevent it?

### 5. How do the results link to ACID?
