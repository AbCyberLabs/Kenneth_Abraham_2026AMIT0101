-- Portfolio 1 and 2: sample data
-- Generates a realistic volume so query speed differences become visible.
-- 20,000 customers, about 30,000 accounts, 300,000 transfers.
--
-- Run with:  psql -U postgres -d kpay -f 02_seed_data.sql

-- Safe to run again: clears old rows first.
TRUNCATE audit_log, transfers, accounts, customers RESTART IDENTITY CASCADE;

INSERT INTO customers (full_name, email, phone, city, created_at)
SELECT
    'Customer ' || g,
    'customer' || g || '@example.com',
    '080' || LPAD(g::text, 8, '0'),
    (ARRAY['Lagos','Abuja','Port Harcourt','Kano','Owerri','Ibadan','Enugu'])[1 + (g % 7)],
    NOW() - ((g % 700) || ' days')::interval
FROM generate_series(1, 20000) AS g;

-- Every customer gets an NGN account.
INSERT INTO accounts (customer_id, account_no, currency, balance)
SELECT customer_id,
       LPAD((1000000000 + customer_id)::text, 10, '0'),
       'NGN',
       ROUND((random() * 500000 + 5000)::numeric, 2)
FROM customers;

-- Every third customer also gets a USD account.
INSERT INTO accounts (customer_id, account_no, currency, balance)
SELECT customer_id,
       LPAD((2000000000 + customer_id)::text, 10, '0'),
       'USD',
       ROUND((random() * 3000 + 50)::numeric, 2)
FROM customers
WHERE customer_id % 3 = 0;

-- 300,000 transfers between random accounts.
INSERT INTO transfers (from_account, to_account, amount, status, narration, created_at)
SELECT f, t, amt, st, 'Payment ' || n, NOW() - ((n % 365) || ' days')::interval - ((n % 86400) || ' seconds')::interval
FROM (
    SELECT n,
           1 + ((n::bigint * 7919) % 20000)::int                   AS f,
           1 + ((n::bigint * 104729 + 13) % 20000)::int            AS t,
           ROUND((random() * 49000 + 500)::numeric, 2) AS amt,
           (ARRAY['SUCCESS','SUCCESS','SUCCESS','SUCCESS','FAILED','PENDING','REVERSED'])[1 + (n % 7)] AS st
    FROM generate_series(1, 300000) AS n
) s
WHERE f <> t;

ANALYZE;

SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL SELECT 'transfers', COUNT(*) FROM transfers;
