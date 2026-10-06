# MIT 8103 Advanced Database Systems: Portfolio

Student: Kenneth Abraham
Programme: Master of Information Technology, Miva Open University
Session: 2026/2027, first semester

## Case study

KPay Wallet, a simulated digital wallet and money transfer platform. All five portfolio activities use this one case study.

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

## Evidence

Screenshots are saved in the `screenshots` folder inside each portfolio folder.

## AI use declaration

See `docs/AI_USE_DECLARATION.md`.
