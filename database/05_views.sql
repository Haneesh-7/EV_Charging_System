-- =====================================================
-- 05_views.sql
-- =====================================================
USE ev_charging_db;

-- Live status of every charger, with the user currently charging (if any)
CREATE OR REPLACE VIEW vw_charger_status AS
SELECT s.name AS station, c.charger_id, ct.name AS connector, c.power_kw,
       t.price_per_kwh, c.status,
       u.full_name AS current_user_name
FROM chargers c
JOIN stations s         ON s.station_id = c.station_id
JOIN connector_types ct ON ct.connector_type_id = c.connector_type_id
JOIN tariffs t          ON t.tariff_id = c.tariff_id
LEFT JOIN charging_sessions cs ON cs.charger_id = c.charger_id AND cs.status = 'Active'
LEFT JOIN users u       ON u.user_id = cs.user_id;

-- Management dashboard per station
CREATE OR REPLACE VIEW vw_station_dashboard AS
SELECT s.station_id, s.name,
       COUNT(DISTINCT c.charger_id) AS chargers,
       COUNT(DISTINCT CASE WHEN c.status = 'Available' THEN c.charger_id END) AS available_now,
       COUNT(DISTINCT CASE WHEN c.status IN ('Faulty','Offline') THEN c.charger_id END) AS out_of_service,
       COUNT(DISTINCT cs.session_id)      AS sessions,
       COALESCE(SUM(cs.energy_kwh),0)     AS energy_kwh,
       COALESCE(SUM(cs.cost),0)           AS revenue
FROM stations s
LEFT JOIN chargers c ON c.station_id = s.station_id
LEFT JOIN charging_sessions cs ON cs.charger_id = c.charger_id AND cs.status <> 'Active'
GROUP BY s.station_id, s.name;

-- Full charging history of users
CREATE OR REPLACE VIEW vw_user_charging_history AS
SELECT u.user_id, u.full_name, v.reg_no, v.model,
       s.name AS station, cs.start_time, cs.end_time,
       cs.start_soc, cs.end_soc, cs.energy_kwh, cs.cost, cs.status
FROM charging_sessions cs
JOIN users u    ON u.user_id = cs.user_id
JOIN vehicles v ON v.vehicle_id = cs.vehicle_id
JOIN chargers c ON c.charger_id = cs.charger_id
JOIN stations s ON s.station_id = c.station_id;

-- Open maintenance tickets for the service team
CREATE OR REPLACE VIEW vw_open_maintenance AS
SELECT m.log_id, s.name AS station, m.charger_id, m.issue, m.reported_at,
       t.full_name AS technician, t.phone,
       TIMESTAMPDIFF(HOUR, m.reported_at, NOW()) AS hours_open
FROM maintenance_logs m
JOIN chargers c    ON c.charger_id = m.charger_id
JOIN stations s    ON s.station_id = c.station_id
JOIN technicians t ON t.technician_id = m.technician_id
WHERE m.resolved_at IS NULL;

-- Monthly revenue by station
CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT DATE_FORMAT(cs.start_time,'%Y-%m') AS month, s.name AS station,
       COUNT(*) AS sessions, SUM(cs.energy_kwh) AS energy_kwh, SUM(cs.cost) AS revenue
FROM charging_sessions cs
JOIN chargers c ON c.charger_id = cs.charger_id
JOIN stations s ON s.station_id = c.station_id
WHERE cs.status <> 'Active'
GROUP BY DATE_FORMAT(cs.start_time,'%Y-%m'), s.station_id, s.name;
