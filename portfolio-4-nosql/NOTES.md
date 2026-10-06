# Portfolio 4 notes: why MongoDB for KPay, and what you give up

Use this to write your explanation of suitability. Put it in your own words.

## What changed from the SQL design

| Relational (PostgreSQL) | Document (MongoDB) |
|---|---|
| customers, accounts and transfers are three tables joined by keys | One wallet document holds the customer, their accounts and recent transfers |
| Fixed columns, every row has the same shape | Each document can have different fields (for example a customer with no tags) |
| Joins to rebuild a customer's view | One read returns everything the app screen needs |

## Where the document model fits KPay

- Showing a customer their wallet screen: one read, no joins.
- Profile data that changes shape over time (new fields for verification, rewards).
- Fast key lookups such as login sessions, with automatic expiry.

## Where it does not fit

- Moving money between two accounts. This needs strong all-or-nothing guarantees. PostgreSQL does this naturally. MongoDB can do multi-document transactions on a replica set, but the relational model is the safer home for balances.
- Reports that join many things together. The aggregation pipeline can do it, but SQL is simpler for ad hoc questions.
- Embedded transfers cannot grow forever, because a document has a 16 MB limit. That is why the model keeps only `recentTransfers` and the full history stays in PostgreSQL.

## A fair conclusion you could write

Use both. PostgreSQL stays the source of truth for balances and transfers. MongoDB serves read-heavy customer profile and session data. This is called polyglot persistence.
