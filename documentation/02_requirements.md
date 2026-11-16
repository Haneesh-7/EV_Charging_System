# Requirements – EV Charging Station Network

## 1. Problem statement
An EV charging company operates stations across a city. It needs a database to track chargers and their health, bookings, live charging sessions, prepaid wallet billing, maintenance and customer feedback, and to report on usage and revenue.

## 2. Users
| User | Needs |
|------|-------|
| EV owner | find compatible chargers, book a slot, charge, pay from wallet, review |
| Network operator | station dashboard, revenue, peak hours, utilisation |
| Maintenance team | open tickets, charger downtime, repair costs |
| Finance | wallet reconciliation, monthly revenue |

## 3. Functional requirements
1. Register users and their vehicles with battery capacity and connector type.
2. Maintain stations, chargers (power, connector, tariff) and tariffs.
3. Show only chargers whose connector matches the vehicle.
4. Reserve a charger for a time window; reject overlapping bookings and faulty or offline chargers.
5. Start a session only if the charger is Available, compatible, and the wallet holds at least 100.
6. On session end: compute energy cost from the charger tariff, debit the wallet (never below zero), free the charger, log a transaction.
7. Record battery % before and after each session.
8. Support wallet top-ups and refunds, with a full ledger.
9. When a fault is reported: mark charger Faulty, interrupt any live session, open a ticket assigned to a technician.
10. Resolve tickets with repair cost and return the charger to service when no other ticket is open.
11. Collect one rating per session.
12. Reports: station revenue and energy, peak hours, connector usage, no-show rate, downtime and maintenance cost, top users, monthly trend.

## 4. Non-functional requirements
- **Integrity:** foreign keys, CHECK and UNIQUE constraints.
- **Atomicity:** billing, session start and fault handling run in transactions.
- **Performance:** indexes for charger status, session time and reservation overlap checks.
- **Auditability:** every wallet movement is stored in `wallet_transactions`.
- **Portability:** MySQL 8.0+.

## 5. Business rules
- A user can charge only a vehicle registered to them.
- Cost = energy delivered (kWh) × tariff price of that charger.
- A reservation can overlap with another only if the other is not in Booked status.
- An interrupted session is billed for energy delivered; refunds are posted as a Refund transaction.

## 6. Assumptions
- Single currency (INR); idle fees are out of scope.
- Energy readings arrive from the charger hardware and are passed to `sp_end_session`.
- One vehicle uses one primary connector type.
