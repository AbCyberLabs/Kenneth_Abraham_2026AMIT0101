# Portfolio 2: Query Processing and Optimisation

## How to run

```
psql -U postgres -d kpay -f queries.sql
```

Better for screenshots: open `psql -U postgres -d kpay` and paste one query at a time.

## What the script does

It runs four queries. For the first three it shows the plan before and after adding an index, using `EXPLAIN (ANALYZE, BUFFERS)`.

| Query | Index added | What to look for |
|---|---|---|
| Q1: last 20 transfers from one account | `(from_account, created_at DESC)` | Plan changes from Seq Scan to an index scan |
| Q2: money sent per city (join of 3 tables) | `accounts(customer_id)` | Almost no change, and that is the lesson |
| Q3: failed transfers in the last 7 days | partial index where status is FAILED | Index scan on a much smaller index |
| Q4: running total with a window function | none | Advanced SQL feature |

## Results from my own run

Fill this table with YOUR numbers from YOUR machine. Times differ between computers.

| Query | Before (ms) | After (ms) | Plan before | Plan after |
|---|---|---|---|---|
| Q1 | | | | |
| Q2 | | | | |
| Q3 | | | | |

For reference, the preparation run on a test server gave roughly 17 ms to 0.1 ms for Q1, 24 ms to 1.3 ms for Q3, and no real change for Q2. Do not copy these. Use your own.

## How to read an execution plan

- **Seq Scan** reads the whole table row by row.
- **Index Scan or Bitmap Index Scan** jumps to the matching rows using an index.
- **actual time** is how long that step took. **rows** is how many rows it returned.
- **Execution Time** at the bottom is the total.

## Analysis to write (3 to 5 sentences each, in your words)

1. Why did Q1 get so much faster? (The database no longer reads 300,000 rows to find about 15.)
2. Why did Q2 barely change? (It reads more than half the table, so a full scan is the cheapest plan.)
3. What does an index cost? Look at the index size query at the bottom of the script. Indexes use disk space and slow down inserts and updates.
4. Why is the Q3 partial index so small?
