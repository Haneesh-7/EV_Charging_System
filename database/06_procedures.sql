-- =====================================================
-- 06_procedures.sql
-- NOTE: these procedures call functions from 07_functions.sql.
-- Run 07_functions.sql before calling any procedure.
-- =====================================================
USE ev_charging_db;
DROP PROCEDURE IF EXISTS sp_topup_wallet;
DROP PROCEDURE IF EXISTS sp_create_reservation;
DROP PROCEDURE IF EXISTS sp_start_session;
DROP PROCEDURE IF EXISTS sp_end_session;
DROP PROCEDURE IF EXISTS sp_report_fault;
DROP PROCEDURE IF EXISTS sp_resolve_fault;
DROP PROCEDURE IF EXISTS sp_station_report;

DELIMITER $$

-- 1. Add money to a user's wallet
CREATE PROCEDURE sp_topup_wallet(IN p_user_id INT, IN p_amount DECIMAL(10,2))
BEGIN
    DECLARE v_wallet_id INT;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Top-up amount must be positive';
    END IF;

    SELECT wallet_id INTO v_wallet_id FROM wallets WHERE user_id = p_user_id;
    IF v_wallet_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wallet not found for user';
    END IF;

    START TRANSACTION;
        UPDATE wallets SET balance = balance + p_amount WHERE wallet_id = v_wallet_id;
        INSERT INTO wallet_transactions (wallet_id, txn_type, amount) VALUES (v_wallet_id, 'TopUp', p_amount);
    COMMIT;
END$$

-- 2. Book a charger slot (blocks overlapping bookings)
CREATE PROCEDURE sp_create_reservation(
    IN  p_user_id    INT,
    IN  p_charger_id INT,
    IN  p_start      DATETIME,
    IN  p_end        DATETIME,
    OUT p_reservation_id INT
)
BEGIN
    DECLARE v_status VARCHAR(20);

    IF p_end <= p_start OR p_start < NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid reservation time window';
    END IF;

    SELECT status INTO v_status FROM chargers WHERE charger_id = p_charger_id;
    IF v_status IS NULL OR v_status IN ('Faulty','Offline') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Charger is not available for booking';
    END IF;

    IF EXISTS (SELECT 1 FROM reservations
               WHERE charger_id = p_charger_id AND status = 'Booked'
                 AND start_time < p_end AND end_time > p_start) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Slot already booked for this charger';
    END IF;

    INSERT INTO reservations (user_id, charger_id, start_time, end_time)
    VALUES (p_user_id, p_charger_id, p_start, p_end);
    SET p_reservation_id = LAST_INSERT_ID();
END$$

-- 3. Start a charging session
CREATE PROCEDURE sp_start_session(
    IN  p_user_id    INT,
    IN  p_vehicle_id INT,
    IN  p_charger_id INT,
    IN  p_start_soc  INT,
    OUT p_session_id INT
)
BEGIN
    DECLARE v_status VARCHAR(20);

    IF NOT EXISTS (SELECT 1 FROM vehicles WHERE vehicle_id = p_vehicle_id AND user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle does not belong to this user';
    END IF;

    SELECT status INTO v_status FROM chargers WHERE charger_id = p_charger_id;
    IF v_status IS NULL OR v_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Charger is not available';
    END IF;

    IF fn_is_compatible(p_vehicle_id, p_charger_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle connector does not match this charger';
    END IF;

    IF fn_wallet_balance(p_user_id) < 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Minimum wallet balance of 100 required';
    END IF;

    START TRANSACTION;
        INSERT INTO charging_sessions (user_id, vehicle_id, charger_id, start_time, start_soc, status)
        VALUES (p_user_id, p_vehicle_id, p_charger_id, NOW(), p_start_soc, 'Active');
        SET p_session_id = LAST_INSERT_ID();
        UPDATE chargers SET status = 'Occupied' WHERE charger_id = p_charger_id;
    COMMIT;
END$$

-- 4. End a session: price it, free the charger, debit the wallet
CREATE PROCEDURE sp_end_session(
    IN p_session_id INT,
    IN p_end_soc    INT,
    IN p_energy_kwh DECIMAL(7,2)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_charger_id INT;
    DECLARE v_status VARCHAR(20);
    DECLARE v_wallet_id INT;
    DECLARE v_cost DECIMAL(10,2);

    SELECT user_id, charger_id, status INTO v_user_id, v_charger_id, v_status
    FROM charging_sessions WHERE session_id = p_session_id;

    IF v_status IS NULL OR v_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Session is not active';
    END IF;

    -- bill is capped at the wallet balance so the balance never goes negative
    SET v_cost = LEAST(fn_session_cost(v_charger_id, p_energy_kwh), fn_wallet_balance(v_user_id));
    SELECT wallet_id INTO v_wallet_id FROM wallets WHERE user_id = v_user_id;

    START TRANSACTION;
        UPDATE charging_sessions
        SET end_time = NOW(), end_soc = p_end_soc, energy_kwh = p_energy_kwh,
            cost = v_cost, status = 'Completed'
        WHERE session_id = p_session_id;

        UPDATE chargers SET status = 'Available' WHERE charger_id = v_charger_id;

        IF v_cost > 0 THEN
            UPDATE wallets SET balance = balance - v_cost WHERE wallet_id = v_wallet_id;
            INSERT INTO wallet_transactions (wallet_id, session_id, txn_type, amount)
            VALUES (v_wallet_id, p_session_id, 'Charge', v_cost);
        END IF;
    COMMIT;
END$$

-- 5. Report a fault: mark the charger faulty, interrupt live session, open a ticket
CREATE PROCEDURE sp_report_fault(
    IN p_charger_id    INT,
    IN p_technician_id INT,
    IN p_issue         VARCHAR(255)
)
BEGIN
    START TRANSACTION;
        UPDATE chargers SET status = 'Faulty' WHERE charger_id = p_charger_id;

        UPDATE charging_sessions
        SET status = 'Interrupted', end_time = NOW()
        WHERE charger_id = p_charger_id AND status = 'Active';

        INSERT INTO maintenance_logs (charger_id, technician_id, issue)
        VALUES (p_charger_id, p_technician_id, p_issue);
    COMMIT;
END$$

-- 6. Close a maintenance ticket and return the charger to service
CREATE PROCEDURE sp_resolve_fault(IN p_log_id INT, IN p_cost DECIMAL(10,2))
BEGIN
    DECLARE v_charger_id INT;

    SELECT charger_id INTO v_charger_id FROM maintenance_logs
    WHERE log_id = p_log_id AND resolved_at IS NULL;

    IF v_charger_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ticket not found or already resolved';
    END IF;

    START TRANSACTION;
        UPDATE maintenance_logs SET resolved_at = NOW(), cost = p_cost WHERE log_id = p_log_id;

        IF NOT EXISTS (SELECT 1 FROM maintenance_logs
                       WHERE charger_id = v_charger_id AND resolved_at IS NULL) THEN
            UPDATE chargers SET status = 'Available' WHERE charger_id = v_charger_id;
        END IF;
    COMMIT;
END$$

-- 7. Station report between two dates
CREATE PROCEDURE sp_station_report(IN p_station_id INT, IN p_from DATE, IN p_to DATE)
BEGIN
    SELECT c.charger_id, ct.name AS connector, c.power_kw,
           COUNT(cs.session_id) AS sessions,
           COALESCE(SUM(cs.energy_kwh),0) AS energy_kwh,
           COALESCE(SUM(cs.cost),0) AS revenue
    FROM chargers c
    JOIN connector_types ct ON ct.connector_type_id = c.connector_type_id
    LEFT JOIN charging_sessions cs ON cs.charger_id = c.charger_id
         AND DATE(cs.start_time) BETWEEN p_from AND p_to AND cs.status <> 'Active'
    WHERE c.station_id = p_station_id
    GROUP BY c.charger_id, ct.name, c.power_kw;
END$$

DELIMITER ;

-- Example:
-- CALL sp_topup_wallet(1, 500);
-- CALL sp_start_session(1, 1, 3, 25, @sid);
-- CALL sp_end_session(@sid, 80, 20.5);
-- CALL sp_report_fault(4, 1, 'Cable damaged');
-- CALL sp_station_report(1, '2026-10-01', '2026-11-30');
