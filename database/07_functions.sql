-- =====================================================
-- 07_functions.sql
-- =====================================================
USE ev_charging_db;
DROP FUNCTION IF EXISTS fn_session_cost;
DROP FUNCTION IF EXISTS fn_session_minutes;
DROP FUNCTION IF EXISTS fn_is_compatible;
DROP FUNCTION IF EXISTS fn_wallet_balance;
DROP FUNCTION IF EXISTS fn_available_chargers;

DELIMITER $$

-- 1. Cost of delivering p_energy kWh on a given charger (uses its tariff)
CREATE FUNCTION fn_session_cost(p_charger_id INT, p_energy DECIMAL(7,2))
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_price DECIMAL(6,2);
    SELECT t.price_per_kwh INTO v_price
    FROM chargers c JOIN tariffs t ON t.tariff_id = c.tariff_id
    WHERE c.charger_id = p_charger_id;
    RETURN ROUND(COALESCE(v_price,0) * p_energy, 2);
END$$

-- 2. Duration of a session in minutes (live sessions use current time)
CREATE FUNCTION fn_session_minutes(p_session_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_mins INT;
    SELECT TIMESTAMPDIFF(MINUTE, start_time, COALESCE(end_time, NOW())) INTO v_mins
    FROM charging_sessions WHERE session_id = p_session_id;
    RETURN v_mins;
END$$

-- 3. 1 if the vehicle's connector fits the charger, else 0
CREATE FUNCTION fn_is_compatible(p_vehicle_id INT, p_charger_id INT)
RETURNS TINYINT(1)
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM vehicles v
    JOIN chargers c ON c.connector_type_id = v.connector_type_id
    WHERE v.vehicle_id = p_vehicle_id AND c.charger_id = p_charger_id;
    RETURN v_count > 0;
END$$

-- 4. Current wallet balance of a user
CREATE FUNCTION fn_wallet_balance(p_user_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_bal DECIMAL(10,2);
    SELECT balance INTO v_bal FROM wallets WHERE user_id = p_user_id;
    RETURN COALESCE(v_bal, 0);
END$$

-- 5. Number of chargers free right now at a station
CREATE FUNCTION fn_available_chargers(p_station_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM chargers
    WHERE station_id = p_station_id AND status = 'Available';
    RETURN v_count;
END$$

DELIMITER ;

-- Usage:
-- SELECT fn_session_cost(3, 30);                -- 660.00
-- SELECT fn_is_compatible(1, 5);                -- 0 (CCS2 car, CHAdeMO charger)
-- SELECT name, fn_available_chargers(station_id) FROM stations;
-- SELECT session_id, fn_session_minutes(session_id) FROM charging_sessions;
