-- =====================================================
-- 03_insert_data.sql  (sample data, Hyderabad network)
-- Cost = energy_kwh x tariff price. Wallet balances match transactions.
-- =====================================================
USE ev_charging_db;

INSERT INTO users (full_name, email, phone) VALUES
('Karthik Reddy','karthik.r@example.com','9811100001'),
('Ananya Iyer',  'ananya.i@example.com', '9811100002'),
('Rohit Verma',  'rohit.v@example.com',  '9811100003'),
('Fatima Begum', 'fatima.b@example.com', '9811100004'),
('Naveen Kumar', 'naveen.k@example.com', '9811100005'),
('Deepa Nair',   'deepa.n@example.com',  '9811100006');

INSERT INTO connector_types (name) VALUES ('CCS2'),('CHAdeMO'),('Type 2 AC'),('Bharat AC-001');

INSERT INTO vehicles (user_id, reg_no, make, model, battery_kwh, connector_type_id) VALUES
(1,'TS09EV1001','Tata',    'Nexon EV',         30.2,1),
(2,'TS08EV2002','MG',      'ZS EV',            50.3,1),
(3,'TS10EV3003','Hyundai', 'Kona Electric',    39.2,1),
(4,'TS07EV4004','Tata',    'Tiago EV',         24.0,3),
(5,'TS09EV5005','Nissan',  'Leaf',             40.0,2),
(6,'TS11EV6006','Hyundai', 'Ioniq 5',          72.6,1),
(3,'TS10EV7007','Mahindra','XUV400',           39.4,1);

INSERT INTO tariffs (name, price_per_kwh, valid_from) VALUES
('AC Standard', 12.00,'2026-01-01'),
('DC Fast',     18.00,'2026-01-01'),
('DC Ultra',    22.00,'2026-01-01');

INSERT INTO stations (name, city, address, latitude, longitude, is_active, opened_on) VALUES
('Madhapur Fast Hub',        'Hyderabad','Inorbit Mall Road, Madhapur',        17.437500,78.391000,TRUE,'2025-03-10'),
('Gachibowli Tech Park',     'Hyderabad','Financial District, Gachibowli',     17.414600,78.349000,TRUE,'2025-06-01'),
('Secunderabad Metro Plaza', 'Hyderabad','Parade Grounds Metro, Secunderabad', 17.439900,78.498300,TRUE,'2025-09-15'),
('Shamshabad Airport Stop',  'Hyderabad','NH44 Airport Highway, Shamshabad',   17.240300,78.429400,TRUE,'2026-01-20');

INSERT INTO chargers (station_id, connector_type_id, tariff_id, power_kw, status, installed_on) VALUES
(1,1,2, 60.0,'Available','2025-03-10'),
(1,3,1,  7.4,'Occupied', '2025-03-10'),
(1,1,3,120.0,'Available','2025-03-10'),
(2,1,2, 60.0,'Available','2025-06-01'),
(2,2,2, 50.0,'Faulty',   '2025-06-01'),
(2,3,1, 22.0,'Available','2025-06-01'),
(3,3,1,  7.4,'Available','2025-09-15'),
(3,1,2, 60.0,'Available','2025-09-15'),
(4,1,3,120.0,'Available','2026-01-20'),
(4,2,2, 60.0,'Offline',  '2026-01-20');

INSERT INTO wallets (user_id, balance) VALUES
(1,346.00),(2,890.00),(3,640.00),(4,356.00),(5,404.00),(6,620.00);

INSERT INTO reservations (user_id, charger_id, start_time, end_time, status) VALUES
(1,1,'2026-10-02 17:45:00','2026-10-02 18:45:00','Completed'),
(2,3,'2026-10-04 09:45:00','2026-10-04 10:45:00','Completed'),
(6,3,'2026-11-01 11:45:00','2026-11-01 12:45:00','Completed'),
(3,4,'2026-11-13 10:00:00','2026-11-13 11:00:00','Booked'),
(1,9,'2026-11-08 16:00:00','2026-11-08 17:00:00','NoShow'),
(6,1,'2026-11-11 18:00:00','2026-11-11 19:00:00','Cancelled');

INSERT INTO charging_sessions (user_id, vehicle_id, charger_id, reservation_id, start_time, end_time,
                               start_soc, end_soc, energy_kwh, cost, status) VALUES
(1,1,1, 1,   '2026-10-02 18:00:00','2026-10-02 18:40:00',20,80,18.00,324.00,'Completed'),
(2,2,3, 2,   '2026-10-04 10:00:00','2026-10-04 10:25:00',25,85,30.00,660.00,'Completed'),
(3,3,4, NULL,'2026-10-06 14:00:00','2026-10-06 14:45:00',30,80,20.00,360.00,'Completed'),
(4,4,6, NULL,'2026-10-08 09:00:00','2026-10-08 11:10:00',20,70,12.00,144.00,'Completed'),
(5,5,5, NULL,'2026-10-09 17:00:00','2026-10-09 17:40:00',20,75,22.00,396.00,'Completed'),
(1,1,9, NULL,'2026-10-20 15:00:00','2026-10-20 15:20:00',25,75,15.00,330.00,'Completed'),
(2,2,1, NULL,'2026-10-25 19:00:00','2026-10-25 19:50:00',30,80,25.00,450.00,'Completed'),
(6,6,3, 3,   '2026-11-01 12:00:00','2026-11-01 12:30:00',15,70,40.00,880.00,'Completed'),
(4,4,2, NULL,'2026-11-12 08:30:00',NULL,                 30,NULL,0.00,  0.00,'Active'),
(5,5,5, NULL,'2026-11-05 12:00:00','2026-11-05 12:10:00',20,32, 5.00, 90.00,'Interrupted');

INSERT INTO wallet_transactions (wallet_id, session_id, txn_type, amount, created_at) VALUES
(1,NULL,'TopUp', 1000.00,'2026-10-01 09:00:00'),
(1,1,   'Charge', 324.00,'2026-10-02 18:40:00'),
(1,6,   'Charge', 330.00,'2026-10-20 15:20:00'),
(2,NULL,'TopUp', 2000.00,'2026-10-03 11:00:00'),
(2,2,   'Charge', 660.00,'2026-10-04 10:25:00'),
(2,7,   'Charge', 450.00,'2026-10-25 19:50:00'),
(3,NULL,'TopUp', 1000.00,'2026-10-05 10:00:00'),
(3,3,   'Charge', 360.00,'2026-10-06 14:45:00'),
(4,NULL,'TopUp',  500.00,'2026-10-07 08:00:00'),
(4,4,   'Charge', 144.00,'2026-10-08 11:10:00'),
(5,NULL,'TopUp',  800.00,'2026-10-08 10:00:00'),
(5,5,   'Charge', 396.00,'2026-10-09 17:40:00'),
(5,10,  'Charge',  90.00,'2026-11-05 12:10:00'),
(5,10,  'Refund',  90.00,'2026-11-05 14:00:00'),
(6,NULL,'TopUp', 1500.00,'2026-10-30 09:00:00'),
(6,8,   'Charge', 880.00,'2026-11-01 12:30:00');

INSERT INTO technicians (full_name, phone, specialization) VALUES
('Srinivas Rao','9822200001','DC fast charger hardware'),
('Pooja Menon', '9822200002','Software and firmware'),
('Imtiyaz Ali', '9822200003','Electrical and AC units');

INSERT INTO maintenance_logs (charger_id, technician_id, issue, reported_at, resolved_at, cost) VALUES
(8, 2,'Firmware update and payment module reset','2026-10-15 10:00:00','2026-10-16 12:00:00',1500.00),
(2, 3,'Display not responding',                  '2026-10-18 09:00:00','2026-10-18 15:00:00', 800.00),
(9, 2,'Quarterly inspection',                    '2026-10-30 08:00:00','2026-10-30 12:00:00', 500.00),
(5, 1,'CHAdeMO cable overheating, session cut',  '2026-11-05 13:00:00',NULL,                    0.00);

INSERT INTO station_reviews (session_id, user_id, station_id, rating, comment) VALUES
(1,1,1,5,'Fast and the app worked smoothly.'),
(2,2,1,4,'Ultra charger is great, parking is tight.'),
(3,3,2,4,'Good location near the office.'),
(4,4,2,4,'Slow but cheap AC charging.'),
(5,5,2,2,'Charger got hot, felt unsafe.'),
(6,1,4,5,'Perfect stop on the airport route.'),
(8,6,1,5,'Charged Ioniq 5 in 30 minutes.');
