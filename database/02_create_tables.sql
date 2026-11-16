-- =====================================================
-- 02_create_tables.sql
-- =====================================================
USE ev_charging_db;

CREATE TABLE users (
    user_id    INT AUTO_INCREMENT PRIMARY KEY,
    full_name  VARCHAR(100) NOT NULL,
    email      VARCHAR(120) NOT NULL UNIQUE,
    phone      VARCHAR(15)  NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE connector_types (
    connector_type_id INT AUTO_INCREMENT PRIMARY KEY,
    name              VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE vehicles (
    vehicle_id        INT AUTO_INCREMENT PRIMARY KEY,
    user_id           INT NOT NULL,
    reg_no            VARCHAR(15) NOT NULL UNIQUE,
    make              VARCHAR(40) NOT NULL,
    model             VARCHAR(40) NOT NULL,
    battery_kwh       DECIMAL(5,1) NOT NULL CHECK (battery_kwh > 0),
    connector_type_id INT NOT NULL,
    CONSTRAINT fk_veh_user      FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_veh_connector FOREIGN KEY (connector_type_id) REFERENCES connector_types(connector_type_id)
);

CREATE TABLE tariffs (
    tariff_id     INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(40) NOT NULL UNIQUE,
    price_per_kwh DECIMAL(6,2) NOT NULL CHECK (price_per_kwh > 0),
    valid_from    DATE NOT NULL
);

CREATE TABLE stations (
    station_id INT AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    city       VARCHAR(60)  NOT NULL,
    address    VARCHAR(200) NOT NULL,
    latitude   DECIMAL(9,6) NOT NULL,
    longitude  DECIMAL(9,6) NOT NULL,
    is_active  BOOLEAN DEFAULT TRUE,
    opened_on  DATE NOT NULL
);

CREATE TABLE chargers (
    charger_id        INT AUTO_INCREMENT PRIMARY KEY,
    station_id        INT NOT NULL,
    connector_type_id INT NOT NULL,
    tariff_id         INT NOT NULL,
    power_kw          DECIMAL(5,1) NOT NULL CHECK (power_kw > 0),
    status            ENUM('Available','Occupied','Faulty','Offline') NOT NULL DEFAULT 'Available',
    installed_on      DATE NOT NULL,
    CONSTRAINT fk_chg_station   FOREIGN KEY (station_id) REFERENCES stations(station_id) ON DELETE CASCADE,
    CONSTRAINT fk_chg_connector FOREIGN KEY (connector_type_id) REFERENCES connector_types(connector_type_id),
    CONSTRAINT fk_chg_tariff    FOREIGN KEY (tariff_id) REFERENCES tariffs(tariff_id)
);

CREATE TABLE wallets (
    wallet_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id   INT NOT NULL UNIQUE,
    balance   DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    CONSTRAINT fk_wal_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE reservations (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    charger_id     INT NOT NULL,
    start_time     DATETIME NOT NULL,
    end_time       DATETIME NOT NULL,
    status         ENUM('Booked','Completed','Cancelled','NoShow') NOT NULL DEFAULT 'Booked',
    CONSTRAINT chk_res_time CHECK (end_time > start_time),
    CONSTRAINT fk_res_user    FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_res_charger FOREIGN KEY (charger_id) REFERENCES chargers(charger_id)
);

CREATE TABLE charging_sessions (
    session_id     INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    vehicle_id     INT NOT NULL,
    charger_id     INT NOT NULL,
    reservation_id INT NULL,
    start_time     DATETIME NOT NULL,
    end_time       DATETIME NULL,
    start_soc      TINYINT NOT NULL CHECK (start_soc BETWEEN 0 AND 100),  -- battery % at start
    end_soc        TINYINT NULL     CHECK (end_soc   BETWEEN 0 AND 100),
    energy_kwh     DECIMAL(7,2) NOT NULL DEFAULT 0,
    cost           DECIMAL(10,2) NOT NULL DEFAULT 0,
    status         ENUM('Active','Completed','Interrupted') NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_ses_user        FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_ses_vehicle     FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
    CONSTRAINT fk_ses_charger     FOREIGN KEY (charger_id) REFERENCES chargers(charger_id),
    CONSTRAINT fk_ses_reservation FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id)
);

CREATE TABLE wallet_transactions (
    txn_id     INT AUTO_INCREMENT PRIMARY KEY,
    wallet_id  INT NOT NULL,
    session_id INT NULL,
    txn_type   ENUM('TopUp','Charge','Refund') NOT NULL,
    amount     DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_txn_wallet  FOREIGN KEY (wallet_id) REFERENCES wallets(wallet_id),
    CONSTRAINT fk_txn_session FOREIGN KEY (session_id) REFERENCES charging_sessions(session_id)
);

CREATE TABLE technicians (
    technician_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    phone         VARCHAR(15) NOT NULL UNIQUE,
    specialization VARCHAR(60) NOT NULL
);

CREATE TABLE maintenance_logs (
    log_id        INT AUTO_INCREMENT PRIMARY KEY,
    charger_id    INT NOT NULL,
    technician_id INT NOT NULL,
    issue         VARCHAR(255) NOT NULL,
    reported_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at   DATETIME NULL,
    cost          DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_log_charger FOREIGN KEY (charger_id) REFERENCES chargers(charger_id),
    CONSTRAINT fk_log_tech    FOREIGN KEY (technician_id) REFERENCES technicians(technician_id)
);

CREATE TABLE station_reviews (
    review_id  INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL UNIQUE,
    user_id    INT NOT NULL,
    station_id INT NOT NULL,
    rating     TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    VARCHAR(300),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rev_session FOREIGN KEY (session_id) REFERENCES charging_sessions(session_id),
    CONSTRAINT fk_rev_user    FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_rev_station FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

-- Indexes
CREATE INDEX idx_chargers_station ON chargers(station_id);
CREATE INDEX idx_chargers_status  ON chargers(status);
CREATE INDEX idx_sessions_user    ON charging_sessions(user_id);
CREATE INDEX idx_sessions_charger ON charging_sessions(charger_id);
CREATE INDEX idx_sessions_start   ON charging_sessions(start_time);
CREATE INDEX idx_res_charger_time ON reservations(charger_id, start_time, end_time);
CREATE INDEX idx_txn_wallet       ON wallet_transactions(wallet_id);
