-- AutoWays: sample data (M-2 Lahore - Islamabad motorway)
-- Run AFTER schema.sql. Safe to re-run: it clears the data tables first.

TRUNCATE Motorway_Corridor, Vehicle_Class, Motorist, Officer_Rank RESTART IDENTITY CASCADE;

-- ============ NETWORK ============
INSERT INTO Motorway_Corridor (route_code, name, origin_city, dest_city, total_length_km, lanes_count, design_speed_kmh) VALUES
('M-2', 'Lahore-Islamabad Motorway', 'Lahore', 'Islamabad', 357.00, 6, 120);

INSERT INTO Motorway_Sector (corridor_id, sector_code, start_km_marker, end_km_marker, hq_city, active_speed_limit_kmh, weather_status) VALUES
(1, 'M2-S1',   0,  95, 'Lahore',         120, 'Clear'),
(1, 'M2-S2',  95, 190, 'Pindi Bhattian', 80,  'Fog'),
(1, 'M2-S3', 190, 280, 'Bhera',          120, 'Clear'),
(1, 'M2-S4', 280, 357, 'Islamabad',      120, 'Clear');

INSERT INTO Interchange (sector_id, name, km_marker, gps_lat, gps_lng, loop_ramps_count, open_status) VALUES
(1, 'Lahore (Thokar Niaz Baig)', 0,   31.450500, 74.225000, 2, 'Open'),
(1, 'Sheikhupura',               40,  31.713100, 73.985000, 2, 'Open'),
(2, 'Pindi Bhattian',            120, 31.896000, 73.274000, 2, 'Open'),
(3, 'Bhera',                     210, 32.485000, 72.909000, 2, 'Open'),
(3, 'Kallar Kahar',              250, 32.777000, 72.700000, 1, 'Restricted'),
(4, 'Islamabad (Chakri)',        357, 33.570000, 72.870000, 3, 'Open');

INSERT INTO Toll_Plaza (interchange_id, plaza_code, direction, total_booths, supervisor_phone) VALUES
(1, 'TP-LHR', 'Both', 8,  '0300-1110001'),
(2, 'TP-SKP', 'Both', 6,  '0300-1110002'),
(3, 'TP-PBH', 'Both', 6,  '0300-1110003'),
(4, 'TP-BHR', 'Both', 6,  '0300-1110004'),
(5, 'TP-KLK', 'Both', 6,  '0300-1110005'),
(6, 'TP-ISB', 'Both', 10, '0300-1110006');

-- 3 lanes per plaza: lane_id = (plaza_id - 1) * 3 + lane_number
INSERT INTO Toll_Lane (plaza_id, lane_number, lane_type, rfid_reader_serial, anpr_unit_serial, barrier_status)
SELECT p.plaza_id, n,
       CASE WHEN n = 3 THEN 'Cash' ELSE 'MTag' END,
       'RFID-' || p.plaza_id || '-' || n,
       'ANPR-' || p.plaza_id || '-' || n,
       'Closed'
FROM Toll_Plaza p CROSS JOIN generate_series(1, 3) AS n
ORDER BY p.plaza_id, n;

-- ============ VEHICLE CLASSES & TARIFFS ============
INSERT INTO Vehicle_Class (class_code, category_name, max_axles, max_gross_weight_kg, base_rate_per_km, class_speed_limit_kmh) VALUES
('CAR',     'Car / Jeep / Van',     2, 3500,  3.00, 120),
('COASTER', 'Mini Bus / Coaster',   2, 8000,  5.00, 100),
('BUS',     'Large Bus',            2, 16000, 7.00, 100),
('TRK2',    '2-Axle Truck',         2, 16000, 8.00, 80),
('TRK3',    'Heavy Multi-Axle Truck', 6, 40000, 12.00, 80);

-- every ordered interchange pair x vehicle class
INSERT INTO Toll_Tariff_Matrix (entry_interchange_id, exit_interchange_id, vclass_id, distance_km, standard_toll_amount, peak_surcharge)
SELECT a.interchange_id, b.interchange_id, v.vclass_id,
       ABS(a.km_marker - b.km_marker),
       ROUND(ABS(a.km_marker - b.km_marker) * v.base_rate_per_km),
       ROUND(ABS(a.km_marker - b.km_marker) * v.base_rate_per_km * 0.10)
FROM Interchange a
CROSS JOIN Interchange b
CROSS JOIN Vehicle_Class v
WHERE a.interchange_id <> b.interchange_id;

-- ============ MOTORISTS, VEHICLES, M-TAGS ============
INSERT INTO Motorist (cnic_no, first_name, last_name, phone, email, license_no, license_expiry, demerit_points, license_status) VALUES
('35202-1111111-1', 'Ahmed',   'Raza',     '0300-2000001', 'ahmed.raza@example.com',   'LHR-L-0001', '2029-03-15', 0,  'Valid'),
('35202-2222222-3', 'Bilal',   'Khan',     '0300-2000002', 'bilal.khan@example.com',   'LHR-L-0002', '2028-07-01', 3,  'Valid'),
('35201-3333333-5', 'Sara',    'Malik',    '0300-2000003', 'sara.malik@example.com',   'LHR-L-0003', '2030-01-20', 2,  'Valid'),
('37405-4444444-7', 'Usman',   'Tariq',    '0300-2000004', 'usman.tariq@example.com',  'RWP-L-0004', '2027-11-30', 0,  'Valid'),
('61101-5555555-9', 'Fatima',  'Noor',     '0300-2000005', 'fatima.noor@example.com',  'ISB-L-0005', '2029-09-09', 5,  'Valid'),
('35202-6666666-2', 'Hassan',  'Ali',      '0300-2000006', 'hassan.ali@example.com',   'LHR-L-0006', '2025-12-31', 0,  'Expired'),
('34101-7777777-4', 'Zainab',  'Shah',     '0300-2000007', 'zainab.shah@example.com',  'GRW-L-0007', '2028-04-18', 3,  'Valid'),
('35202-8888888-6', 'Imran',   'Siddiqui', '0300-2000008', 'imran.sid@example.com',    'LHR-L-0008', '2029-06-25', 0,  'Valid'),
('37405-9999999-8', 'Kamran',  'Butt',     '0300-2000009', 'kamran.butt@example.com',  'RWP-L-0009', '2028-02-14', 0,  'Valid'),
('61101-1010101-0', 'Ayesha',  'Rehman',   '0300-2000010', 'ayesha.rehman@example.com','ISB-L-0010', '2027-08-08', 20, 'Suspended');

INSERT INTO Registered_Vehicle (motorist_id, vclass_id, plate_no, chassis_no, make_model, manufacture_year, fitness_status) VALUES
(1,  1, 'LEA-2301', 'CHS-1001', 'Toyota Corolla',   2019, 'Fit'),
(2,  1, 'LHR-4512', 'CHS-1002', 'Honda Civic',      2021, 'Fit'),
(3,  1, 'LEB-7788', 'CHS-1003', 'Suzuki Cultus',    2018, 'Fit'),
(4,  1, 'RIA-3320', 'CHS-1004', 'Toyota Yaris',     2022, 'Fit'),
(5,  1, 'ICT-1199', 'CHS-1005', 'Kia Sportage',     2020, 'Fit'),
(6,  1, 'LED-5566', 'CHS-1006', 'Honda City',       2017, 'Expired'),
(7,  1, 'GAA-4040', 'CHS-1007', 'Suzuki Alto',      2016, 'Fit'),
(8,  2, 'LEC-8100', 'CHS-1008', 'Toyota Coaster',   2015, 'Fit'),
(9,  3, 'RLB-2020', 'CHS-1009', 'Hino Bus',         2014, 'Fit'),
(10, 1, 'ICT-9090', 'CHS-1010', 'Hyundai Tucson',   2021, 'Fit'),
(9,  5, 'RLC-7700', 'CHS-1011', 'Hino 700 Trailer', 2013, 'Fit'),
(8,  4, 'LEF-6600', 'CHS-1012', 'Isuzu Forward',    2012, 'Unfit');

-- one M-Tag per vehicle 1-10 (1:1)
INSERT INTO MTag_Account (vehicle_id, rfid_tag_uid, wallet_balance, min_balance_threshold, auto_topup_flag, issued_date, status) VALUES
(1,  'MTAG-0001', 4500.00, 500, TRUE,  '2025-01-10', 'Active'),
(2,  'MTAG-0002', 2200.00, 500, FALSE, '2025-02-14', 'Active'),
(3,  'MTAG-0003', 800.00,  500, FALSE, '2025-03-01', 'Active'),
(4,  'MTAG-0004', 6000.00, 500, TRUE,  '2025-04-22', 'Active'),
(5,  'MTAG-0005', 150.00,  500, FALSE, '2025-05-05', 'Active'),
(6,  'MTAG-0006', 0.00,    500, FALSE, '2024-11-11', 'Blocked'),
(7,  'MTAG-0007', 3100.00, 500, TRUE,  '2025-06-30', 'Active'),
(8,  'MTAG-0008', 9000.00, 1000, TRUE, '2025-07-19', 'Active'),
(9,  'MTAG-0009', 12000.00,1000, TRUE, '2025-08-02', 'Active'),
(10, 'MTAG-0010', 1000.00, 500, FALSE, '2025-09-12', 'Suspended');

INSERT INTO MTag_Topup_Payment (mtag_id, amount, payment_channel, transaction_ref, paid_at, status) VALUES
(1, 5000.00,  'JazzCash',  'TXN-100001', NOW() - INTERVAL '20 days', 'Success'),
(2, 3000.00,  'Easypaisa', 'TXN-100002', NOW() - INTERVAL '15 days', 'Success'),
(3, 1000.00,  'Bank App',  'TXN-100003', NOW() - INTERVAL '12 days', 'Success'),
(4, 10000.00, 'Card',      'TXN-100004', NOW() - INTERVAL '10 days', 'Success'),
(5, 500.00,   'JazzCash',  'TXN-100005', NOW() - INTERVAL '8 days',  'Failed'),
(7, 4000.00,  'Easypaisa', 'TXN-100006', NOW() - INTERVAL '6 days',  'Success'),
(8, 10000.00, 'Bank App',  'TXN-100007', NOW() - INTERVAL '4 days',  'Success'),
(9, 15000.00, 'Card',      'TXN-100008', NOW() - INTERVAL '3 days',  'Success'),
(1, 2000.00,  'JazzCash',  'TXN-100009', NOW() - INTERVAL '1 day',   'Pending');

-- ============ OFFICERS & FLEET ============
INSERT INTO Officer_Rank (rank_code, title, pay_scale, command_authority) VALUES
('SP',    'Superintendent of Police',  'BPS-18', 'Sector Command'),
('DSP',   'Deputy Superintendent',     'BPS-17', 'Zone Command'),
('INSP',  'Inspector',                 'BPS-16', 'Unit Command'),
('SI',    'Sub-Inspector',             'BPS-14', 'Patrol Team'),
('CONST', 'Constable',                 'BPS-07', 'Patrol Duty');

INSERT INTO Patrol_Officer (rank_id, base_sector_id, badge_no, first_name, last_name, phone, hire_date, duty_status) VALUES
(1, 1, 'NHMP-0001', 'Tahir',   'Mehmood', '0301-3000001', '2012-04-01', 'Active'),
(2, 2, 'NHMP-0002', 'Nadeem',  'Akhtar',  '0301-3000002', '2014-08-15', 'Active'),
(3, 1, 'NHMP-0003', 'Shahid',  'Iqbal',   '0301-3000003', '2016-02-10', 'Active'),
(3, 3, 'NHMP-0004', 'Rashid',  'Hussain', '0301-3000004', '2016-09-01', 'Active'),
(4, 2, 'NHMP-0005', 'Faisal',  'Javed',   '0301-3000005', '2018-03-20', 'Active'),
(4, 4, 'NHMP-0006', 'Adeel',   'Anwar',   '0301-3000006', '2019-07-07', 'On Leave'),
(5, 3, 'NHMP-0007', 'Waqas',   'Ahmad',   '0301-3000007', '2021-01-12', 'Active'),
(5, 4, 'NHMP-0008', 'Junaid',  'Ali',     '0301-3000008', '2022-05-30', 'Active');

INSERT INTO Officer_Certification (officer_id, cert_type, training_academy, issued_date, expiry_date) VALUES
(1, 'Highway Command',       'National Police Academy', '2019-05-01', '2029-05-01'),
(3, 'First Aid & Rescue',    'NHMP Training Centre',    '2023-02-01', '2026-02-01'),
(5, 'Radar & ANPR Handling', 'NHMP Training Centre',    '2022-06-15', '2027-06-15'),
(7, 'Heavy Vehicle Recovery','NHMP Training Centre',    '2024-01-10', '2028-01-10'),
(8, 'First Aid & Rescue',    'NHMP Training Centre',    '2024-03-05', '2027-03-05');

INSERT INTO Patrol_Fleet_Unit (base_sector_id, call_sign, unit_type, reg_plate, odometer_km, gps_lat, gps_lng, operational_status) VALUES
(1, 'ALPHA-1',   'Patrol Car',     'NH-1001', 48200, 31.700000, 74.000000, 'Available'),
(1, 'MEDIC-1',   'Ambulance',      'NH-1002', 61500, 31.450500, 74.225000, 'Available'),
(2, 'BRAVO-2',   'Patrol Car',     'NH-2001', 52300, 31.896000, 73.274000, 'On Patrol'),
(3, 'CRANE-3',   'Recovery Crane', 'NH-3001', 30100, 32.485000, 72.909000, 'Available'),
(4, 'DELTA-4',   'Patrol Car',     'NH-4001', 75800, 33.570000, 72.870000, 'In Maintenance'),
(4, 'BIKE-4',    'Highway Bike',   'NH-4002', 12400, 33.400000, 72.900000, 'Available');

INSERT INTO Patrol_Shift_Assignment (unit_id, officer_id, sector_id, shift_role, start_time, end_time) VALUES
(1, 3, 1, 'Driver',     NOW() - INTERVAL '6 hours', NOW() + INTERVAL '2 hours'),
(1, 1, 1, 'Commander',  NOW() - INTERVAL '6 hours', NOW() + INTERVAL '2 hours'),
(3, 5, 2, 'Driver',     NOW() - INTERVAL '5 hours', NOW() + INTERVAL '3 hours'),
(3, 2, 2, 'Commander',  NOW() - INTERVAL '5 hours', NOW() + INTERVAL '3 hours'),
(4, 7, 3, 'Operator',   NOW() - INTERVAL '4 hours', NOW() + INTERVAL '4 hours'),
(6, 8, 4, 'Rider',      NOW() - INTERVAL '3 hours', NOW() + INTERVAL '5 hours');

INSERT INTO Fleet_Maintenance_Record (unit_id, workshop_name, service_type, performed_on, next_due_km, cost) VALUES
(1, 'NHMP Workshop Lahore', 'Oil Change',       CURRENT_DATE - 30,  53000, 18500.00),
(3, 'NHMP Workshop Pindi',  'Brake Service',    CURRENT_DATE - 45,  57000, 42000.00),
(5, 'NHMP Workshop Isb',    'Engine Overhaul',  CURRENT_DATE - 5,   80000, 185000.00),
(2, 'NHMP Workshop Lahore', 'Oil Change',       CURRENT_DATE - 60,  66000, 21000.00),
(4, 'NHMP Workshop Bhera',  'Hydraulic Check',  CURRENT_DATE - 20,  35000, 27500.00);

INSERT INTO Fleet_Fuel_Log (unit_id, shift_id, liters_filled, odometer_reading, fuel_cost, logged_at) VALUES
(1, 1, 45.00, 48150, 13500.00, NOW() - INTERVAL '7 hours'),
(3, 3, 40.50, 52250, 12150.00, NOW() - INTERVAL '6 hours'),
(4, 5, 60.00, 30050, 18000.00, NOW() - INTERVAL '5 hours'),
(6, 6, 12.00, 12350, 3600.00,  NOW() - INTERVAL '4 hours'),
(1, NULL, 38.00, 48000, 11400.00, NOW() - INTERVAL '2 days');

-- ============ TOLL TRIPS ============
-- lane_id = (plaza_id - 1) * 3 + lane_number ; MTag lanes are numbers 1-2
INSERT INTO Toll_Transit_Trip (mtag_id, entry_lane_id, exit_lane_id, entry_time, exit_time, computed_avg_speed_kmh, toll_deducted, trip_status) VALUES
(1, 1,  16, NOW() - INTERVAL '2 days 5 hours',   NOW() - INTERVAL '2 days 2 hours',            119.0, 1071.00, 'Completed'),
(2, 2,  17, NOW() - INTERVAL '2 days 4 hours',   NOW() - INTERVAL '2 days 1 hour 20 minutes',  133.9, 1071.00, 'Violation'),
(3, 2,  7,  NOW() - INTERVAL '1 day 10 hours',   NOW() - INTERVAL '1 day 8 hours 50 minutes',  102.9, 360.00,  'Completed'),
(4, 16, 1,  NOW() - INTERVAL '1 day 6 hours',    NOW() - INTERVAL '1 day 2 hours 55 minutes',  115.7, 1071.00, 'Completed'),
(5, 4,  10, NOW() - INTERVAL '1 day 3 hours',    NOW() - INTERVAL '1 day 1 hour 30 minutes',   113.3, 510.00,  'Completed'),
(6, 11, 13, NOW() - INTERVAL '20 hours',         NOW() - INTERVAL '19 hours 38 minutes',       109.1, 120.00,  'Completed'),
(7, 1,  5,  NOW() - INTERVAL '12 hours',         NOW() - INTERVAL '11 hours 42 minutes',       133.3, 120.00,  'Violation'),
(10, 8, 14, NOW() - INTERVAL '9 hours',          NOW() - INTERVAL '7 hours 45 minutes',        104.0, 390.00,  'Completed'),
(9, 7,  16, NOW() - INTERVAL '8 hours',          NOW() - INTERVAL '5 hours',                    79.0, 1659.00, 'Completed'),
(8, 17, NULL, NOW() - INTERVAL '30 minutes',     NULL,                                          NULL, 0.00,    'In Transit'),
(9, 2,  NULL, NOW() - INTERVAL '10 minutes',     NULL,                                          NULL, 0.00,    'In Transit');

-- ============ ENFORCEMENT ============
INSERT INTO Weighbridge_Station (interchange_id, station_code, max_scale_tons, calibration_due_date, status) VALUES
(1, 'WB-LHR', 80.0, CURRENT_DATE + 90,  'Active'),
(4, 'WB-BHR', 80.0, CURRENT_DATE + 30,  'Active'),
(6, 'WB-ISB', 80.0, CURRENT_DATE - 10,  'Calibration Due');

INSERT INTO Axle_Weight_Log (wb_id, vehicle_id, measured_weight_kg, overload_kg, weighed_at, action_taken) VALUES
(1, 11, 46500, 6500, NOW() - INTERVAL '2 days',  'Fined and offloaded'),
(2, 12, 15200, 0,    NOW() - INTERVAL '1 day',   'Cleared'),
(3, 11, 39800, 0,    NOW() - INTERVAL '10 hours','Cleared'),
(1, 9,  16900, 900,  NOW() - INTERVAL '5 hours', 'Warning issued'),
(2, 11, 44200, 4200, NOW() - INTERVAL '3 hours', 'Fined');

INSERT INTO ANPR_Speed_Camera (sector_id, km_marker, direction, radar_limit_kmh, last_calibrated_on, status) VALUES
(1, 20,  'Northbound', 120, CURRENT_DATE - 60, 'Active'),
(1, 70,  'Southbound', 120, CURRENT_DATE - 45, 'Active'),
(2, 130, 'Northbound', 80,  CURRENT_DATE - 30, 'Active'),
(3, 220, 'Southbound', 120, CURRENT_DATE - 90, 'Active'),
(3, 265, 'Northbound', 120, CURRENT_DATE - 15, 'Faulty'),
(4, 330, 'Northbound', 120, CURRENT_DATE - 20, 'Active');

INSERT INTO E_Challan_Ticket (vehicle_id, camera_id, trip_id, officer_id, violation_type, recorded_speed_kmh, fine_amount, demerit_added, issued_at, payment_status) VALUES
(2,  NULL, 2,    NULL, 'Average Speed Violation', 133.9, 5000.00,  3, NOW() - INTERVAL '2 days 1 hour',  'Unpaid'),
(7,  NULL, 7,    NULL, 'Average Speed Violation', 133.3, 5000.00,  3, NOW() - INTERVAL '11 hours',       'Unpaid'),
(5,  2,    NULL, NULL, 'Speeding (ANPR Camera)',  142.0, 8000.00,  5, NOW() - INTERVAL '3 days',         'Paid'),
(3,  NULL, NULL, 1,    'Lane Violation',          NULL,  2000.00,  2, NOW() - INTERVAL '1 day 5 hours',  'Unpaid'),
(11, NULL, NULL, 4,    'Overloading',             NULL,  25000.00, 0, NOW() - INTERVAL '2 days',         'Disputed');

INSERT INTO Blacklisted_Vehicle_Alert (vehicle_id, watch_reason, fir_reference, flagged_at, intercepted_lane_id, alert_status) VALUES
(6,  'Reported stolen',               'FIR-2026/1187', NOW() - INTERVAL '5 days', NULL, 'Active'),
(12, 'Suspected fake number plate',   'FIR-2026/1203', NOW() - INTERVAL '3 days', 4,    'Intercepted');

-- ============ ROAD MONITORING ============
INSERT INTO Weather_Visibility_Sensor (sector_id, km_marker, visibility_meters, fog_density_pct, road_surface_temp_c, wind_speed_kmh, logged_at) VALUES
(1, 30,  2500, 5.00,  14.5, 8,  NOW() - INTERVAL '1 hour'),
(2, 110, 150,  88.00, 9.0,  3,  NOW() - INTERVAL '1 hour'),
(2, 150, 220,  75.50, 9.5,  4,  NOW() - INTERVAL '45 minutes'),
(3, 230, 1800, 12.00, 13.0, 10, NOW() - INTERVAL '30 minutes'),
(4, 320, 3000, 2.00,  15.0, 12, NOW() - INTERVAL '20 minutes'),
(2, 110, 300,  70.00, 9.0,  3,  NOW() - INTERVAL '3 hours');

INSERT INTO Variable_Message_Sign (sector_id, km_marker, direction, displayed_message, posted_speed_limit_kmh, last_updated_at, power_status) VALUES
(1, 25,  'Northbound', 'Road clear. Drive safely.',                120, NOW() - INTERVAL '2 hours', 'On'),
(2, 105, 'Northbound', 'DENSE FOG AHEAD. Reduce speed to 80.',      80,  NOW() - INTERVAL '1 hour',  'On'),
(2, 160, 'Southbound', 'Fog. Keep headlights on. Max 80 km/h.',     80,  NOW() - INTERVAL '1 hour',  'On'),
(3, 245, 'Northbound', 'Kallar Kahar exit restricted.',             120, NOW() - INTERVAL '4 hours', 'On'),
(4, 300, 'Southbound', 'Sign offline for maintenance.',             NULL, NOW() - INTERVAL '1 day',  'Off');

INSERT INTO Service_Rest_Area (sector_id, name, km_marker, direction, parking_capacity, fuel_station_flag, trauma_center_flag) VALUES
(1, 'Sheikhupura Service Area',  45,  'Both', 120, TRUE,  FALSE),
(2, 'Pindi Bhattian Rest Area',  125, 'Both', 200, TRUE,  TRUE),
(3, 'Kallar Kahar Rest Area',    255, 'Both', 150, TRUE,  FALSE),
(4, 'Balkassar Service Area',    300, 'Both', 180, TRUE,  TRUE);

-- ============ INCIDENTS ============
INSERT INTO Highway_Incident (sector_id, km_marker, incident_type, severity, lanes_blocked, reported_at, cleared_at, status) VALUES
(2, 142, 'Fog Pile-up',   'Critical', 2, NOW() - INTERVAL '2 hours',  NULL,                       'Dispatched'),
(1, 55,  'Breakdown',     'Low',      1, NOW() - INTERVAL '1 day',    NOW() - INTERVAL '23 hours','Cleared'),
(3, 228, 'Accident',      'High',     1, NOW() - INTERVAL '30 minutes', NULL,                     'Open'),
(4, 310, 'Debris on Road','Medium',   1, NOW() - INTERVAL '3 days',   NOW() - INTERVAL '3 days' + INTERVAL '40 minutes', 'Cleared'),
(1, 12,  'Vehicle Fire',  'High',     2, NOW() - INTERVAL '2 days',   NOW() - INTERVAL '2 days' + INTERVAL '1 hour 30 minutes', 'Cleared');

INSERT INTO Incident_Rescue_Dispatch (incident_id, unit_id, dispatched_at, arrived_at, response_mins, hospital_handoff, resolution_notes) VALUES
(1, 3, NOW() - INTERVAL '1 hour 55 minutes', NOW() - INTERVAL '1 hour 40 minutes', 15, 'DHQ Hospital Gujrat',  'Multiple vehicles involved; lanes partially open.'),
(1, 4, NOW() - INTERVAL '1 hour 50 minutes', NULL,                                 NULL, NULL,                 'Crane en route.'),
(2, 1, NOW() - INTERVAL '1 day',             NOW() - INTERVAL '23 hours 40 minutes', 20, NULL,                  'Vehicle towed to service area.'),
(4, 6, NOW() - INTERVAL '3 days',            NOW() - INTERVAL '3 days' + INTERVAL '12 minutes', 12, NULL,       'Debris removed.'),
(5, 2, NOW() - INTERVAL '2 days',            NOW() - INTERVAL '2 days' + INTERVAL '18 minutes', 18, 'Mayo Hospital Lahore', 'Driver treated for minor burns.');