-- =====================================================
-- 04_queries.sql
-- =====================================================
USE ev_charging_db;

-- Q1. Network overview: chargers and installed power per station
SELECT s.name, COUNT(c.charger_id) AS chargers, SUM(c.power_kw) AS total_kw
FROM stations s
LEFT JOIN chargers c ON c.station_id = s.station_id
GROUP BY s.station_id, s.name;

-- Q2. Revenue and energy delivered per station
SELECT s.name, COUNT(cs.session_id) AS sessions,
       SUM(cs.energy_kwh) AS energy_kwh, SUM(cs.cost) AS revenue
FROM stations s
JOIN chargers c ON c.station_id = s.station_id
JOIN charging_sessions cs ON cs.charger_id = c.charger_id AND cs.status <> 'Active'
GROUP BY s.station_id, s.name
ORDER BY revenue DESC;

-- Q3. Peak charging hours
SELECT HOUR(start_time) AS hour_of_day, COUNT(*) AS sessions
FROM charging_sessions
GROUP BY HOUR(start_time)
ORDER BY sessions DESC, hour_of_day;

-- Q4. Average duration and energy by connector type (completed sessions)
SELECT ct.name AS connector,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, cs.start_time, cs.end_time)),1) AS avg_minutes,
       ROUND(AVG(cs.energy_kwh),2) AS avg_kwh
FROM charging_sessions cs
JOIN chargers c ON c.charger_id = cs.charger_id
JOIN connector_types ct ON ct.connector_type_id = c.connector_type_id
WHERE cs.status = 'Completed'
GROUP BY ct.connector_type_id, ct.name;

-- Q5. Top users by energy consumed
SELECT u.full_name, SUM(cs.energy_kwh) AS total_kwh, SUM(cs.cost) AS total_spent
FROM users u
JOIN charging_sessions cs ON cs.user_id = u.user_id
GROUP BY u.user_id, u.full_name
ORDER BY total_kwh DESC;

-- Q6. Chargers that are down, with their open maintenance ticket
SELECT s.name AS station, c.charger_id, c.status, m.issue, m.reported_at
FROM chargers c
JOIN stations s ON s.station_id = c.station_id
LEFT JOIN maintenance_logs m ON m.charger_id = c.charger_id AND m.resolved_at IS NULL
WHERE c.status IN ('Faulty','Offline');

-- Q7. Reservation outcome share
SELECT status, COUNT(*) AS reservations,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM reservations), 1) AS pct
FROM reservations
GROUP BY status;

-- Q8. Vehicles that have never charged
SELECT v.reg_no, v.make, v.model
FROM vehicles v
LEFT JOIN charging_sessions cs ON cs.vehicle_id = v.vehicle_id
WHERE cs.session_id IS NULL;

-- Q9. Monthly energy and revenue
SELECT DATE_FORMAT(start_time,'%Y-%m') AS month,
       COUNT(*) AS sessions, SUM(energy_kwh) AS energy_kwh, SUM(cost) AS revenue
FROM charging_sessions
WHERE status <> 'Active'
GROUP BY DATE_FORMAT(start_time,'%Y-%m')
ORDER BY month;

-- Q10. Running total of spending per user (window function)
SELECT u.full_name, cs.start_time, cs.cost,
       SUM(cs.cost) OVER (PARTITION BY u.user_id ORDER BY cs.start_time) AS running_spend
FROM charging_sessions cs
JOIN users u ON u.user_id = cs.user_id
WHERE cs.status <> 'Active'
ORDER BY u.full_name, cs.start_time;

-- Q11. Stations ranked by revenue (RANK)
SELECT name, revenue, RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM (
    SELECT s.name, COALESCE(SUM(cs.cost),0) AS revenue
    FROM stations s
    LEFT JOIN chargers c ON c.station_id = s.station_id
    LEFT JOIN charging_sessions cs ON cs.charger_id = c.charger_id
    GROUP BY s.station_id, s.name
) t;

-- Q12. Users spending more than the average per-session cost (subquery)
SELECT DISTINCT u.full_name
FROM charging_sessions cs
JOIN users u ON u.user_id = cs.user_id
WHERE cs.cost > (SELECT AVG(cost) FROM charging_sessions WHERE status = 'Completed');

-- Q13. Available chargers compatible with vehicle 1
SELECT s.name AS station, c.charger_id, c.power_kw, t.price_per_kwh
FROM vehicles v
JOIN chargers c ON c.connector_type_id = v.connector_type_id
JOIN stations s ON s.station_id = c.station_id
JOIN tariffs t  ON t.tariff_id = c.tariff_id
WHERE v.vehicle_id = 1 AND c.status = 'Available'
ORDER BY t.price_per_kwh, c.power_kw DESC;

-- Q14. Average station rating with review count
SELECT s.name, ROUND(AVG(r.rating),2) AS avg_rating, COUNT(*) AS reviews
FROM station_reviews r
JOIN stations s ON s.station_id = r.station_id
GROUP BY s.station_id, s.name
ORDER BY avg_rating DESC;

-- Q15. Maintenance cost and downtime hours per charger
SELECT m.charger_id, COUNT(*) AS tickets, SUM(m.cost) AS total_cost,
       SUM(TIMESTAMPDIFF(HOUR, m.reported_at, COALESCE(m.resolved_at, NOW()))) AS downtime_hours
FROM maintenance_logs m
GROUP BY m.charger_id
ORDER BY downtime_hours DESC;

-- Q16. Effective price per kWh by tariff
SELECT t.name, ROUND(SUM(cs.cost)/SUM(cs.energy_kwh),2) AS effective_price
FROM charging_sessions cs
JOIN chargers c ON c.charger_id = cs.charger_id
JOIN tariffs t  ON t.tariff_id = c.tariff_id
WHERE cs.energy_kwh > 0
GROUP BY t.tariff_id, t.name;

-- Q17. Wallet reconciliation: stored balance vs transaction history (should be 0 difference)
SELECT w.user_id, w.balance,
       SUM(CASE WHEN wt.txn_type = 'Charge' THEN -wt.amount ELSE wt.amount END) AS computed_balance
FROM wallets w
JOIN wallet_transactions wt ON wt.wallet_id = w.wallet_id
GROUP BY w.wallet_id, w.user_id, w.balance;
