# MIT 8103 Advanced Database Systems: Portfolio

Student: Kenneth Abraham

Student ID: 2026/A/MIT/0101

Programme: Master of Information Technology

Session: 2026/2027, first semester

## Case study

KPay Wallet is a fictional digital wallet and money transfer service for Nigerian users. Customers open wallet accounts in naira (NGN) or US dollars (USD) and send money to each other. All five portfolio activities use this one case study.

**Users of the database:** customers (through a mobile app), customer support staff, and auditors who check balances.

**Major data stored:** customer details, wallet accounts in NGN and USD, transfers between accounts, and an audit log of balance changes.

**Key operations:** open an account, send money between accounts, view a statement, reverse a failed transfer, and audit balance changes.

## Repository layout

| Folder | Activity | Tools |
|---|---|---|
| `portfolio-1-database-design` | ER diagram, schema, keys, constraints, normalisation | PostgreSQL |
| `portfolio-2-query-optimisation` | Queries, execution plans, indexes | PostgreSQL |
| `portfolio-3-transactions-concurrency` | COMMIT, ROLLBACK, isolation, locks, deadlock | PostgreSQL |
| `portfolio-4-nosql` | Document model of the same data | MongoDB |
| `portfolio-5-distributed-cloud` | Replica set, failover, consistency, sharding discussion | MongoDB, Docker |

## How to reproduce

1. Install PostgreSQL 16 and create a database called `kpay`.
2. Run the scripts in `portfolio-1-database-design`, then 2, then 3, in the order given in each README.
3. Install Docker Desktop and follow `portfolio-4-nosql` and `portfolio-5-distributed-cloud`.

Notes: 01_schema.sql drops and recreates the four tables, so run it on an empty kpay database. The seed data uses random values, so amounts, the Query 4 running total and timings will differ slightly from my screenshots. The row counts (20000, 26666 and 300000) and the plan types should stay the same, and the Query 3 count depends on the date. Portfolio 5 needs Docker Desktop and free ports 27017 to 27019.

## Evidence

Screenshots are saved in the `screenshots` folder inside each portfolio folder.

## AI use declaration

See `docs/AI_USE_DECLARATION.md`.
