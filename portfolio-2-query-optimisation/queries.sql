-- Portfolio 2: Query Processing and Optimisation
-- Run in order. Take a screenshot of each EXPLAIN ANALYZE result.
--
-- Run with:  psql -U postgres -d kpay -f queries.sql
-- (or paste the blocks into psql one at a time so you can screenshot each)

\timing on

-- Start from a clean state: remove the extra indexes so "before" is honest.
DROP INDEX IF EXISTS idx_transfers_from_created;
DROP INDEX IF EXISTS idx_transfers_status_created;
DROP INDEX IF EXISTS idx_customers_city;
DROP INDEX IF EXISTS idx_accounts_customer;
ANALYZE;

----------------------------------------------------------------------
-- Q1. Statement history for one account (most recent first)
----------------------------------------------------------------------
-- Business question: show the last 20 transfers sent from account 4521.
SELECT transfer_id, to_account, amount, status, created_at
FROM transfers
WHERE from_account = 4521
ORDER BY created_at DESC
LIMIT 20;

-- BEFORE the index
EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, to_account, amount, status, created_at
FROM transfers
WHERE from_account = 4521
ORDER BY created_at DESC
LIMIT 20;

-- Add a composite index: filter column first, sort column second.
CREATE INDEX idx_transfers_from_created ON transfers (from_account, created_at DESC);
ANALYZE transfers;

-- AFTER the index
EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, to_account, amount, status, created_at
FROM transfers
WHERE from_account = 4521
ORDER BY created_at DESC
LIMIT 20;

----------------------------------------------------------------------
-- Q2. Join and aggregate: total successful money sent per city
----------------------------------------------------------------------
-- Business question: which cities send the most money (successful transfers)?
SELECT c.city,
       COUNT(*)      AS number_of_transfers,
       SUM(t.amount) AS total_sent
FROM transfers t
JOIN accounts  a ON a.account_id  = t.from_account
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.status = 'SUCCESS'
GROUP BY c.city
ORDER BY total_sent DESC;

-- BEFORE
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.city, COUNT(*) AS number_of_transfers, SUM(t.amount) AS total_sent
FROM transfers t
JOIN accounts  a ON a.account_id  = t.from_account
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.status = 'SUCCESS'
GROUP BY c.city
ORDER BY total_sent DESC;

-- Index on the foreign key used by the join.
CREATE INDEX idx_accounts_customer ON accounts (customer_id);
ANALYZE accounts;

-- AFTER (compare the plan and the timing).
-- Expect little or no improvement here. This query reads more than half of the
-- transfers table, so PostgreSQL correctly prefers a full scan and ignores the
-- new index. That is a finding worth writing about: an index only helps when a
-- query touches a small part of the table.
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.city, COUNT(*) AS number_of_transfers, SUM(t.amount) AS total_sent
FROM transfers t
JOIN accounts  a ON a.account_id  = t.from_account
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.status = 'SUCCESS'
GROUP BY c.city
ORDER BY total_sent DESC;

----------------------------------------------------------------------
-- Q3. A rare value: failed transfers in the last 7 days
----------------------------------------------------------------------
-- A partial index only stores the rows you care about, so it stays small.
SELECT COUNT(*)
FROM transfers
WHERE status = 'FAILED' AND created_at > NOW() - INTERVAL '7 days';

-- BEFORE
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM transfers
WHERE status = 'FAILED' AND created_at > NOW() - INTERVAL '7 days';

CREATE INDEX idx_transfers_failed_recent ON transfers (created_at) WHERE status = 'FAILED';
ANALYZE transfers;

-- AFTER
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM transfers
WHERE status = 'FAILED' AND created_at > NOW() - INTERVAL '7 days';

----------------------------------------------------------------------
-- Q4. Window function: running total per account
----------------------------------------------------------------------
-- Advanced SQL: a running total of what account 4521 has sent over time.
SELECT transfer_id,
       created_at,
       amount,
       SUM(amount) OVER (ORDER BY created_at) AS running_total
FROM transfers
WHERE from_account = 4521 AND status = 'SUCCESS'
ORDER BY created_at;

----------------------------------------------------------------------
-- Index size check (shows the cost side of indexing)
----------------------------------------------------------------------
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname IN ('transfers','accounts')
ORDER BY pg_relation_size(indexrelid) DESC;
