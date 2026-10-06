# Portfolio 1: Database Design and Modelling

## Case study: KPay Wallet

KPay Wallet is a simulated digital wallet and money transfer platform for Nigerian users. It is not a real company. I chose it because money movement forces careful design: balances must never go negative, transfers must be recorded exactly, and every change must be traceable.

**Users of the database:** customers (through a mobile app), customer support staff, and auditors who check balances.

**Major data stored:** customer details, wallet accounts in NGN and USD, transfers between accounts, and an audit log of balance changes.

**Key operations:** open an account, send money between accounts, view a statement, reverse a failed transfer, and audit balance changes.

## Files

| File | What it does |
|---|---|
| `01_schema.sql` | Creates the four tables with keys and constraints |
| `02_seed_data.sql` | Fills them with 20,000 customers, about 26,000 accounts and 300,000 transfers |
| `er_diagram.png` | Entity relationship diagram |

## How to run

```
psql -U postgres -c "CREATE DATABASE kpay;"
psql -U postgres -d kpay -f 01_schema.sql
psql -U postgres -d kpay -f 02_seed_data.sql
```

## Design decisions

- **customers to accounts is one to many.** One person can hold an NGN and a USD account.
- **accounts to transfers is one to many, twice.** A transfer has a sending account and a receiving account, so transfers holds two foreign keys to accounts.
- **audit_log** is separate so history is never mixed into the live balance.
- **Constraints do real work.** `CHECK (balance >= 0)` stops overdrafts. `CHECK (amount > 0)` stops negative transfers. `CHECK (from_account <> to_account)` stops sending money to yourself. `UNIQUE` on email, phone and account number stops duplicates. `ON DELETE RESTRICT` on accounts stops a customer being deleted while they still own accounts.
- **NUMERIC(14,2) for money.** Floating point types give rounding errors with money.

## Normalisation

**First normal form (1NF).** Every column holds one value. A customer's accounts are not stored as a list inside the customer row. They are separate rows in accounts.

**Second normal form (2NF).** Every table has a single column primary key, so no column can depend on only part of a key.

**Third normal form (3NF).** No non key column depends on another non key column. For example, a customer's city lives in customers only. It is not repeated in accounts or transfers. If it were, changing a customer's city would mean updating many rows and risking mismatches.

**A deliberate trade off.** Balance is stored on the account even though it could be calculated by adding every transfer. This breaks pure normalisation, but it makes reading a balance instant. The audit log and the transfers table let us check the stored balance against the history.

## Questions I should be able to answer

1. Why is `balance` stored when it could be calculated?
2. What would go wrong if city were stored in the accounts table?
3. Why does transfers have two foreign keys to the same table?
