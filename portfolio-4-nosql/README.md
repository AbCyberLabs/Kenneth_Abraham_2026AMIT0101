# Portfolio 4: NoSQL and advanced data models

This part models the KPay Wallet in MongoDB. In PostgreSQL a wallet needed three tables (customers, accounts and transfers). Here one document holds the customer, their accounts and their recent transfers together.

## Files in this folder

| File | What it is |
|---|---|
| mongo_kpay.js | The starter script with the data and the queries |
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

### 2. What did the queries and the update show?

### 3. What did the index change, and what did the unique index do?

### 4. What does the TTL index do?

### 5. Where does MongoDB suit KPay, and where does it not?

### 6. What I did not test

## State of the database after my run

The wallets collection holds the three test wallets and the unique index email_1. The sessions collection is empty because the test session expired. mongo_kpay.js starts with `db.wallets.drop()`, so running it again removes the wallets and the index and builds everything again. That also removes any test wallets made in Portfolio 5.
