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

Measured on 11 October 2026, PostgreSQL 16.15 on Windows. Times differ between computers.

| Query | Before (ms) | After (ms) | Plan before | Plan after |
|---|---|---|---|---|
| Q1 | 75.237 | 0.122 | Parallel Seq Scan | Bitmap Index Scan |
| Q2 | 210.859 | 170.380 | Seq Scans, Hash Joins | Same plan, index unused |
| Q3 | 89.303 | 0.220 | Parallel Seq Scan | Index Only Scan |

Q3 uses NOW(), so its count changes with the date. It was 789 on 11 October 2026.

## Screenshots

| File | What it shows |
|---|---|
| p2_01_q1_before.png | Q1 before the index: Parallel Seq Scan, 75.237 ms |
| p2_02_q1_after.png | Q1 after the index: Bitmap Index Scan, 0.122 ms |
| p2_03_q2_before.png | Q2 before: three tables joined, 210.859 ms |
| p2_04_q2_after.png | Q2 after: same plan, index not used, 170.380 ms |
| p2_05_q3_before.png | Q3 before: Parallel Seq Scan, 89.303 ms |
| p2_06_q3_after.png | Q3 after: Index Only Scan, 0.220 ms |
| p2_07_q4_result.png | Q4 running total, 9 rows, last total 295933.31 |
| p2_08_index_sizes.png | Size of every index on transfers and accounts |

## How to read an execution plan

- **Seq Scan** reads the whole table row by row.
- **Index Scan or Bitmap Index Scan** jumps to the matching rows using an index.
- **actual time** is how long that step took. **rows** is how many rows it returned.
- **Execution Time** at the bottom is the total.

## Analysis

### 1. Why did Q1 get so much faster?
Before the index was added, PostgreSQL had to scan all 300,000 rows in the transfers table using a Parallel Seq Scan to find transfers belonging to account 4521[cite: 48]. This operation took 75.237 ms and evaluated 3,188 shared memory blocks[cite: 48]. After creating the composite index on `(from_account, created_at DESC)`, the planner switched to a Bitmap Index Scan[cite: 48]. It jumped directly to the 15 matching records, reading only 18 blocks while completely skipping the other 299,985 rows, reducing execution time to 0.122 ms (over 600 times faster)[cite: 48].

### 2. Why did Q2 barely change?
Query 2 aggregates total transfer amounts grouped by city for all successful transactions, requiring the database to process around 171,000 of the 300,000 rows in the transfers table (over 70% of the records) alongside the accounts and customers tables. When a query reads such a large portion of a table, a sequential scan reading contiguous disk blocks is far more efficient than making tens of thousands of random index block lookups[cite: 34, 48]. Consequently, PostgreSQL ignored the new index on `accounts(customer_id)` and retained the original `Parallel Seq Scan` and `Hash Join` plan[cite: 34, 35, 48]. Although the recorded time moved from 210.859 ms to 170.380 ms, subsequent test runs produced times of 169.417 ms, 206.493 ms, and 175.893 ms, confirming that this gap is merely normal system run-to-run variation rather than an indexing improvement[cite: 42, 46, 48].

3. What does an index cost? Look at the index size query at the bottom of the script. Indexes use disk space and slow down inserts and updates.
4. Why is the Q3 partial index so small?
