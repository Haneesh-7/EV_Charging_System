-- =====================================================
-- 01_create_database.sql
-- Project : EV Charging Station Network Management
-- Requires: MySQL 8.0+
-- =====================================================
DROP DATABASE IF EXISTS ev_charging_db;

CREATE DATABASE ev_charging_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE ev_charging_db;
