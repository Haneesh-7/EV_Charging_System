-- Run from inside the database/ folder:
--   mysql -u root -p < run_all.sql
SOURCE 01_create_database.sql;
SOURCE 02_create_tables.sql;
SOURCE 03_insert_data.sql;
SOURCE 05_views.sql;
SOURCE 07_functions.sql;
SOURCE 06_procedures.sql;
-- Report queries (SELECTs): mysql -u root -p ev_charging_db < 04_queries.sql
