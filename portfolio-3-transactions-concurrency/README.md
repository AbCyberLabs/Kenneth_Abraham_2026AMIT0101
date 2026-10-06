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

## ACID in one line each (to use in your write up)

- **Atomicity:** all steps of a transaction happen or none do.
- **Consistency:** the rules (constraints) are never broken by a committed transaction.
- **Isolation:** transactions running together do not see each other's half finished work, to a degree set by the isolation level.
- **Durability:** once committed, the data survives a crash.

## Questions I should be able to answer

1. Why did the lost update happen in Experiment 1?
2. What exactly did `FOR UPDATE` make Session B do?
3. Why does locking the smaller account id first prevent deadlocks?
