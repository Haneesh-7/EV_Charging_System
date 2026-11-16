# EV Charging Station Network – MySQL Project

A database for an electric-vehicle charging company: stations, chargers, tariffs, bookings, live sessions, prepaid wallets, maintenance and reviews.

## Folder structure
```
ev_charging_project/
├── database/
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_insert_data.sql
│   ├── 04_queries.sql
│   ├── 05_views.sql
│   ├── 06_procedures.sql
│   ├── 07_functions.sql
│   └── run_all.sql
└── documentation/
    ├── 01_database_design.md
    ├── 02_requirements.md
    └── 03_er_diagram.md / .png / .svg
```

## Run (MySQL 8.0+)
```bash
cd database
mysql -u root -p < run_all.sql
mysql -u root -p ev_charging_db < 04_queries.sql
```
Run `07_functions.sql` before calling any procedure.

## Demo
```sql
USE ev_charging_db;
CALL sp_topup_wallet(1, 500);
CALL sp_start_session(1, 1, 3, 25, @sid);   -- user 1, Nexon EV, charger 3 (CCS2 120kW)
SELECT * FROM vw_charger_status WHERE charger_id = 3;
CALL sp_end_session(@sid, 85, 20.0);         -- bills 20 kWh x 22 = 440
SELECT * FROM wallet_transactions ORDER BY txn_id DESC LIMIT 2;

CALL sp_start_session(1, 1, 5, 40, @x);      -- fails: charger 5 is faulty / wrong connector
SELECT * FROM vw_open_maintenance;
```
