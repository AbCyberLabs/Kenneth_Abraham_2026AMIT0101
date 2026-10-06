// Portfolio 4: NoSQL and Advanced Data Models
// Same case study (KPay Wallet), modelled as MongoDB documents.
//
// Run inside the Mongo shell:
//     docker exec -it mongo1 mongosh
//     load("/scripts/mongo_kpay.js")        // if you mounted this folder at /scripts
// or paste the blocks into mongosh one at a time.

use("kpay");
db.wallets.drop();

// ---------------------------------------------------------------------------
// MODEL: one document per customer wallet, with recent transfers EMBEDDED.
// In SQL this took three tables (customers, accounts, transfers) and joins.
// In MongoDB the data that is read together is stored together.
// ---------------------------------------------------------------------------
db.wallets.insertMany([
  {
    _id: "C0001",
    fullName: "Ada Obi",
    email: "ada@example.com",
    city: "Lagos",
    accounts: [
      { accountNo: "1000000001", currency: "NGN", balance: 80000 },
      { accountNo: "2000000001", currency: "USD", balance: 450 }
    ],
    recentTransfers: [
      { to: "1000000002", amount: 20000, status: "SUCCESS", note: "Rent contribution", at: new Date("2026-09-30T10:15:00Z") },
      { to: "1000000003", amount: 1500,  status: "SUCCESS", note: "Airtime",           at: new Date("2026-10-01T08:00:00Z") }
    ],
    tags: ["premium", "verified"]
  },
  {
    _id: "C0002",
    fullName: "Chidi Eze",
    email: "chidi@example.com",
    city: "Owerri",
    accounts: [{ accountNo: "1000000002", currency: "NGN", balance: 70000 }],
    recentTransfers: [
      { to: "1000000001", amount: 500, status: "FAILED", note: "Wrong account", at: new Date("2026-10-02T12:30:00Z") }
    ],
    tags: ["verified"]
  },
  {
    _id: "C0003",
    fullName: "Zainab Musa",
    email: "zainab@example.com",
    city: "Kano",
    accounts: [{ accountNo: "1000000003", currency: "NGN", balance: 152000 }],
    recentTransfers: [],
    tags: []
  }
]);

// ---------------------------------------------------------------------------
// QUERIES (screenshot each result)
// ---------------------------------------------------------------------------

// 1. Find one wallet by email
db.wallets.find({ email: "ada@example.com" });

// 2. Customers in Lagos or Kano
db.wallets.find({ city: { $in: ["Lagos", "Kano"] } }, { fullName: 1, city: 1, _id: 0 });

// 3. Search inside an embedded array: wallets that have a FAILED transfer
db.wallets.find({ "recentTransfers.status": "FAILED" }, { fullName: 1, _id: 0 });

// 4. Update inside an array: add 1000 to Ada's NGN account
db.wallets.updateOne(
  { _id: "C0001", "accounts.currency": "NGN" },
  { $inc: { "accounts.$.balance": 1000 } }
);

// 5. Aggregation pipeline: total NGN balance per city
db.wallets.aggregate([
  { $unwind: "$accounts" },
  { $match: { "accounts.currency": "NGN" } },
  { $group: { _id: "$city", totalBalance: { $sum: "$accounts.balance" }, wallets: { $sum: 1 } } },
  { $sort: { totalBalance: -1 } }
]);

// 6. Aggregation: total successful money sent per customer
db.wallets.aggregate([
  { $unwind: "$recentTransfers" },
  { $match: { "recentTransfers.status": "SUCCESS" } },
  { $group: { _id: "$fullName", totalSent: { $sum: "$recentTransfers.amount" } } },
  { $sort: { totalSent: -1 } }
]);

// 7. Index and proof it is used
db.wallets.createIndex({ email: 1 }, { unique: true });
db.wallets.find({ email: "ada@example.com" }).explain("executionStats");
// In the output, look for  stage: "IXSCAN"  (index used) and totalDocsExamined: 1

// ---------------------------------------------------------------------------
// OPTIONAL: key-value style example (fast lookup of a session or balance cache)
// ---------------------------------------------------------------------------
db.sessions.drop();
db.sessions.insertOne({ _id: "sess_8f3a21", customerId: "C0001", expiresAt: new Date(Date.now() + 15 * 60 * 1000) });
db.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });   // Mongo deletes it automatically after expiry
db.sessions.findOne({ _id: "sess_8f3a21" });
