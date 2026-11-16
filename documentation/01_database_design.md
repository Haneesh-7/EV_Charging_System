# Database Design – EV Charging Station Network

**Database:** `ev_charging_db`  **Engine:** MySQL 8.0 (InnoDB, utf8mb4)

## 1. Design approach
- Normalised to **3NF**. Connector types, tariffs and stations are separate lookup/master tables, so a price change or a new connector type is a one-row update.
- `charging_sessions` stores the final `energy_kwh` and `cost`, a billing snapshot that does not change when a tariff changes later.
- Wallet balance is kept in `wallets` for fast reads and backed by `wallet_transactions` as an audit trail (see reconciliation query Q17).
- Charger availability is tracked in `chargers.status` and changed only by stored procedures, inside transactions.

## 2. Tables (13)

| # | Table | Purpose |
|---|-------|---------|
| 1 | users | EV owners using the network |
| 2 | connector_types | CCS2, CHAdeMO, Type 2 AC, Bharat AC-001 |
| 3 | vehicles | Registered EVs with battery size and connector |
| 4 | tariffs | Price per kWh plans (AC Standard, DC Fast, DC Ultra) |
| 5 | stations | Charging locations with GPS coordinates |
| 6 | chargers | Individual charging points, power, status and tariff |
| 7 | wallets | Prepaid balance, one per user |
| 8 | wallet_transactions | TopUp, Charge and Refund ledger |
| 9 | reservations | Booked time slots on a charger |
| 10 | charging_sessions | Every charge: SOC before/after, kWh, cost, status |
| 11 | technicians | Service staff |
| 12 | maintenance_logs | Fault tickets and repair cost |
| 13 | station_reviews | One rating per session |

## 3. Relationships

| Parent | Child | Type |
|--------|-------|------|
| users | vehicles, wallets (1:1), reservations, charging_sessions, station_reviews | 1 : N |
| connector_types | vehicles, chargers | 1 : N |
| tariffs | chargers | 1 : N |
| stations | chargers, station_reviews | 1 : N |
| chargers | reservations, charging_sessions, maintenance_logs | 1 : N |
| vehicles | charging_sessions | 1 : N |
| reservations | charging_sessions | 1 : 0..1 (optional link) |
| wallets | wallet_transactions | 1 : N |
| charging_sessions | wallet_transactions | 1 : N (charge, refund) |
| charging_sessions | station_reviews | 1 : 0..1 (`session_id` UNIQUE) |
| technicians | maintenance_logs | 1 : N |

## 4. Key columns
- `chargers.status`: Available, Occupied, Faulty, Offline
- `charging_sessions.status`: Active, Completed, Interrupted; `start_soc` / `end_soc` are battery % (0–100); `end_time` and `end_soc` are NULL while Active
- `reservations.status`: Booked, Completed, Cancelled, NoShow
- `wallet_transactions.txn_type`: TopUp, Charge, Refund
- `maintenance_logs.resolved_at` NULL means the ticket is open

## 5. Constraints
- UNIQUE: email, phone, reg_no, wallets.user_id, station_reviews.session_id, tariff name
- CHECK: price > 0, power > 0, balance >= 0, SOC 0–100, rating 1–5, reservation end > start
- Cascade delete: vehicles, wallet, chargers follow their parent

## 6. Indexes
Charger by station and status; sessions by user, charger and start time; reservation lookup on (charger, start, end) for overlap checks; wallet transactions by wallet.

## 7. Database programming objects
| Type | Objects |
|------|---------|
| Procedures | sp_topup_wallet, sp_create_reservation, sp_start_session, sp_end_session, sp_report_fault, sp_resolve_fault, sp_station_report |
| Functions | fn_session_cost, fn_session_minutes, fn_is_compatible, fn_wallet_balance, fn_available_chargers |
| Views | vw_charger_status, vw_station_dashboard, vw_user_charging_history, vw_open_maintenance, vw_monthly_revenue |
