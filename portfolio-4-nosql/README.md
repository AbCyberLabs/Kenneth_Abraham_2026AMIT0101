# Portfolio 4: NoSQL and advanced data models

This part models the KPay Wallet in MongoDB. In PostgreSQL a wallet needed three tables (customers, accounts and transfers). Here one document holds the customer, their accounts and their recent transfers together.

## Files in this folder

| File | What it is |
|---|---|
| mongo_kpay.js | The starter script with the data and the queries. I ran it as it is, with the four changes listed in "What I changed from mongo_kpay.js" below |
| screenshots | Ten pictures from my own run, p4_01 to p4_10 |
| README.md | This file |

## How to run it

I ran this on 12 October 2026 on Windows 11 with Docker Desktop. It uses the MongoDB 7 replica set from Portfolio 5: three servers called mongo1, mongo2 and mongo3, and the set is called kpayrs.

1. Start the servers. In PowerShell, go to the portfolio-5-distributed-cloud folder and run `docker compose up -d`. The first time only, join the servers into a replica set with steps 1 and 2 of the Portfolio 5 README.
2. Open a shell that is connected to the replica set:

```
docker exec -it mongo1 mongosh "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/kpay?replicaSet=kpayrs"
```

The prompt should read `kpayrs [primary] kpay>`.

3. Paste the commands from mongo_kpay.js one at a time, each as one line, and take a screenshot of each result. Typing `cls` clears the screen between screenshots. I pasted the commands and did not use `load()`, because `load()` runs a file but does not print the results of the queries.

## What I changed from mongo_kpay.js

1. The first query uses a projection, `{ fullName: 1, email: 1, city: 1 }`, so the output is short.
2. For explain I used this one line, which prints only the plan and the two counts. I ran it twice, before and after creating the index:

```
var e = db.wallets.find({ email: "ada@example.com" }).explain("executionStats"); ({ plan: e.queryPlanner.winningPlan.queryPlan || e.queryPlanner.winningPlan, keysExamined: e.executionStats.totalKeysExamined, docsExamined: e.executionStats.totalDocsExamined })
```

3. I added a test that the unique index refuses a duplicate email:

```
db.wallets.insertOne({ _id: "C0004", fullName: "Duplicate Test", email: "ada@example.com", city: "Abuja" })
```

4. The test session expires after 60 seconds instead of 15 minutes, so the automatic delete can be seen within a few minutes:

```
db.sessions.drop(); db.sessions.insertOne({ _id: "sess_8f3a21", customerId: "C0001", expiresAt: new Date(Date.now() + 60 * 1000) }); db.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 })
```

## Results from my own run

| Picture | Step | Result |
|---|---|---|
| p4_01 | Insert 3 wallets | acknowledged: true, ids C0001, C0002 and C0003 |
| p4_02 | findOne on C0001 | Ada Obi's whole record (details, accounts, recent transfers, tags) comes back in one read |
| p4_03 | Three find queries | By email: Ada Obi, Lagos. City in Lagos or Kano: Ada Obi and Zainab Musa. A FAILED transfer: Chidi Eze |
| p4_04 | Update inside an array | matchedCount 1, modifiedCount 1. Ada's NGN balance went from 80000 to 81000, USD stayed 450 |
| p4_05 | Two aggregations | NGN total per city: Kano 152000, Lagos 81000, Owerri 70000 (1 wallet each). Successful money sent: Ada Obi 21500 |
| p4_06 | Explain before the index | COLLSCAN, keysExamined 0, docsExamined 3 |
| p4_07 | Unique index, then explain | Index email_1 created. FETCH over IXSCAN, keysExamined 1, docsExamined 1 |
| p4_08 | Duplicate email | Refused: E11000 duplicate key error collection: kpay.wallets index: email_1 |
| p4_09 | Session and TTL index | sess_8f3a21 expires at 2026-10-12T16:04:22.005Z (UTC). Indexes _id_ and expiresAt_1, with expireAfterSeconds 0 |
| p4_10 | After the 60 seconds | findOne on the same session returns null, so it was deleted automatically |

Lagos shows 81000 because the update in p4_04 ran before the aggregation. Chidi Eze is missing from the second aggregation because his only transfer is FAILED, and that pipeline keeps only SUCCESS.

## Screenshots

All files are in the screenshots folder.

| File | What it shows |
|---|---|
| p4_01_insert_wallets.png | The three wallets inserted |
| p4_02_one_wallet_document.png | One wallet document with its accounts and transfers inside |
| p4_03_find_queries.png | Search by email, by city with $in, and by FAILED status inside the transfers |
| p4_04_update_balance.png | Adding 1000 to Ada's NGN account with the positional $ |
| p4_05_aggregations.png | NGN balance per city, and successful money sent per customer |
| p4_06_explain_before_index.png | COLLSCAN, 3 documents read |
| p4_07_explain_after_index.png | IXSCAN on email_1, 1 document read |
| p4_08_duplicate_email_blocked.png | The unique index refusing a duplicate email |
| p4_09_session_created.png | A test session and the TTL index |
| p4_10_session_expired.png | The session is gone, findOne returns null |

## Analysis

### 1. How does the document model differ from my SQL tables, and what did I embed?

In the SQL schema, retrieving a single wallet view required joining records across `customers`, `accounts`, and `transfers` tables. In contrast, MongoDB encapsulates Ada Obi's profile details, her NGN and USD accounts, her two recent transfers, and her verification tags inside a single document within the `wallets` collection, enabling `findOne` to retrieve the entire wallet state in one read operation. Only recent transfers are embedded inside the document to respect MongoDB's strict 16 MB document size boundary, ensuring active wallets do not exceed storage limits over years of activity; historical transfer archives remain safely stored in PostgreSQL.

### 2. What did the queries and the update show?

Targeted find operations verified document filtering: an email lookup retrieved Ada Obi in Lagos, an `$in` query filtered customers in Lagos or Kano (Ada Obi and Zainab Musa), and dot-notation query `"recentTransfers.status": "FAILED"` inspected embedded sub-documents to identify Chidi Eze. The array update utilized the positional `$` operator (`"accounts.$.balance"`) to target only the NGN account item without modifying the USD account, successfully updating Ada's NGN balance from 80,000 to 81,000 while leaving her USD balance unchanged at 450 (`matchedCount: 1`, `modifiedCount: 1`).

The aggregation pipelines demonstrated complex data processing: the first pipeline used `$unwind` on account arrays, filtered for NGN currency via `$match`, and grouped by city to report NGN totals of Kano (152,000), Lagos (81,000), and Owerri (70,000). The second pipeline filtered embedded transfers for `SUCCESS` status and summed outgoing money per sender, returning Ada Obi with 21,500 (combining 20,000 and 1,500) while intentionally excluding Chidi Eze's 500 failed attempt.

### 3. What did the index change, and what did the unique index do?

Execution plan analysis on `email` lookups highlighted the efficiency gain of indexing. Prior to index creation, searching for `ada@example.com` triggered a full collection scan (`COLLSCAN`) that evaluated all 3 documents in the collection (`keysExamined: 0`, `docsExamined: 3`). After building a unique index on `email`, the plan transitioned to an index scan (`IXSCAN`) wrapped in a `FETCH` stage, bringing work counts down to `keysExamined: 1` and `docsExamined: 1`. While the performance delta on 3 documents is negligible, index lookups scale logarithmically rather than linearly as data volume expands. Furthermore, attempting to insert a second wallet with `ada@example.com` triggered an `E11000 duplicate key error` on index `email_1`, confirming that unique indexes enforce key constraints equivalent to SQL `UNIQUE` rules.

### 4. What does the TTL index do?

The `sessions` collection demonstrates key-value document patterns and automated data retention. A session document (`sess_8f3a21`) was written with an `expiresAt` timestamp set 60 seconds into the future, coupled with a TTL index on `expiresAt` configured with `expireAfterSeconds: 0`. Upon querying the session after the expiration window passed, `findOne` returned `null`, confirming that MongoDB's background thread automatically removed the expired document without explicit delete operations.

### 5. Where does MongoDB suit KPay, and where does it not?

MongoDB excels in managing entity data that benefits from single-read access patterns or flexible structures, such as customer profile management, verification status tags, and self-expiring authentication sessions. However, core fund transfers demand strict transactional integrity. Moving funds between accounts requires updating two balances atomically, a requirement tested and proven under PostgreSQL row-level locks and ACID guarantees in Portfolio 3. Furthermore, relational SQL structures remain better suited for multi-table financial reporting and unbounded ledger records that cannot fit within MongoDB's 16 MB document limit. Consequently, KPay is best architected using polyglot persistence: PostgreSQL handles core transactional balances and ledger records, while MongoDB handles user profiles, tags, and session management.

### 6. What I did not test

This test used 3 sample wallet documents on a local Docker replica set, so it shows how each feature works and not how MongoDB behaves with a large amount of data. I measured how many documents each query read, not how long it took in milliseconds. I also did not test multi document transactions across the replica set, so I can't say how MongoDB would handle moving money between two wallets.

## State of the database after my run

The wallets collection holds the three test wallets and the unique index email_1. The sessions collection is empty because the test session expired. mongo_kpay.js starts with `db.wallets.drop()`, so running it again removes the wallets and the index and builds everything again. That also removes any test wallets made in Portfolio 5.
