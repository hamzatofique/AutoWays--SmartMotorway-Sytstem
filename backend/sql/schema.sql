-- AutoWays: Smart Motorway, M-Tag Toll & Patrol Operations
-- Day 2: Schema (29 tables), PostgreSQL
-- Run order matters: parent tables come before the tables that reference them.

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ============ MODULE 1: Network structure ============

CREATE TABLE Motorway_Corridor (
  corridor_id      SERIAL PRIMARY KEY,
  route_code       VARCHAR(10)  NOT NULL UNIQUE,
  name             VARCHAR(100) NOT NULL,
  origin_city      VARCHAR(60)  NOT NULL,
  dest_city        VARCHAR(60)  NOT NULL,
  total_length_km  NUMERIC(6,2) NOT NULL CHECK (total_length_km > 0),
  lanes_count      INT          NOT NULL CHECK (lanes_count > 0),
  design_speed_kmh INT          NOT NULL CHECK (design_speed_kmh > 0)
);

CREATE TABLE Motorway_Sector (
  sector_id              SERIAL PRIMARY KEY,
  corridor_id            INT NOT NULL REFERENCES Motorway_Corridor(corridor_id) ON DELETE CASCADE,
  sector_code            VARCHAR(20) NOT NULL UNIQUE,
  start_km_marker        INT NOT NULL,
  end_km_marker          INT NOT NULL,
  hq_city                VARCHAR(60),
  active_speed_limit_kmh INT NOT NULL CHECK (active_speed_limit_kmh > 0),
  weather_status         VARCHAR(30) NOT NULL DEFAULT 'Clear',
  CHECK (end_km_marker > start_km_marker)
);

CREATE TABLE Interchange (
  interchange_id   SERIAL PRIMARY KEY,
  sector_id        INT NOT NULL REFERENCES Motorway_Sector(sector_id) ON DELETE CASCADE,
  name             VARCHAR(80) NOT NULL,
  km_marker        INT NOT NULL,
  gps_lat          DECIMAL(9,6),
  gps_lng          DECIMAL(9,6),
  loop_ramps_count INT NOT NULL DEFAULT 0,
  open_status      VARCHAR(20) NOT NULL DEFAULT 'Open'
    CHECK (open_status IN ('Open','Closed','Restricted'))
);

CREATE TABLE Toll_Plaza (
  plaza_id         SERIAL PRIMARY KEY,
  interchange_id   INT NOT NULL REFERENCES Interchange(interchange_id) ON DELETE CASCADE,
  plaza_code       VARCHAR(20) NOT NULL UNIQUE,
  direction        VARCHAR(15) NOT NULL,
  total_booths     INT NOT NULL CHECK (total_booths > 0),
  supervisor_phone VARCHAR(20)
);

CREATE TABLE Toll_Lane (
  lane_id            SERIAL PRIMARY KEY,
  plaza_id           INT NOT NULL REFERENCES Toll_Plaza(plaza_id) ON DELETE CASCADE,
  lane_number        INT NOT NULL,
  lane_type          VARCHAR(20) NOT NULL CHECK (lane_type IN ('MTag','Cash','Mixed')),
  rfid_reader_serial VARCHAR(40) UNIQUE,
  anpr_unit_serial   VARCHAR(40) UNIQUE,
  barrier_status     VARCHAR(20) NOT NULL DEFAULT 'Closed'
    CHECK (barrier_status IN ('Open','Closed','Fault')),
  UNIQUE (plaza_id, lane_number)
);

-- ============ MODULE 2: Vehicles, M-Tag & Tolls ============

CREATE TABLE Vehicle_Class (
  vclass_id             SERIAL PRIMARY KEY,
  class_code            VARCHAR(15) NOT NULL UNIQUE,
  category_name         VARCHAR(60) NOT NULL,
  max_axles             INT NOT NULL CHECK (max_axles > 0),
  max_gross_weight_kg   INT NOT NULL CHECK (max_gross_weight_kg > 0),
  base_rate_per_km      NUMERIC(6,2) NOT NULL CHECK (base_rate_per_km >= 0),
  class_speed_limit_kmh INT NOT NULL CHECK (class_speed_limit_kmh > 0)
);

CREATE TABLE Motorist (
  motorist_id    SERIAL PRIMARY KEY,
  cnic_no        VARCHAR(15) NOT NULL UNIQUE,
  first_name     VARCHAR(50) NOT NULL,
  last_name      VARCHAR(50) NOT NULL,
  phone          VARCHAR(20),
  email          VARCHAR(80) UNIQUE,
  license_no     VARCHAR(30) UNIQUE,
  license_expiry DATE,
  demerit_points INT NOT NULL DEFAULT 0 CHECK (demerit_points >= 0),
  license_status VARCHAR(20) NOT NULL DEFAULT 'Valid'
    CHECK (license_status IN ('Valid','Suspended','Expired','Revoked'))
);

CREATE TABLE Registered_Vehicle (
  vehicle_id        SERIAL PRIMARY KEY,
  motorist_id       INT NOT NULL REFERENCES Motorist(motorist_id) ON DELETE CASCADE,
  vclass_id         INT NOT NULL REFERENCES Vehicle_Class(vclass_id),
  plate_no          VARCHAR(20) NOT NULL UNIQUE,
  chassis_no        VARCHAR(40) NOT NULL UNIQUE,
  make_model        VARCHAR(60),
  manufacture_year  INT CHECK (manufacture_year >= 1980),
  fitness_status    VARCHAR(20) NOT NULL DEFAULT 'Fit'
    CHECK (fitness_status IN ('Fit','Unfit','Expired'))
);

CREATE TABLE MTag_Account (
  mtag_id               SERIAL PRIMARY KEY,
  vehicle_id            INT NOT NULL UNIQUE REFERENCES Registered_Vehicle(vehicle_id) ON DELETE CASCADE,  -- 1:1
  rfid_tag_uid          VARCHAR(40) NOT NULL UNIQUE,
  wallet_balance        NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (wallet_balance >= 0),
  min_balance_threshold NUMERIC(8,2)  NOT NULL DEFAULT 0,
  auto_topup_flag       BOOLEAN NOT NULL DEFAULT FALSE,
  issued_date           DATE NOT NULL DEFAULT CURRENT_DATE,
  status                VARCHAR(20) NOT NULL DEFAULT 'Active'
    CHECK (status IN ('Active','Suspended','Blocked','Closed'))
);

CREATE TABLE MTag_Topup_Payment (
  topup_id        SERIAL PRIMARY KEY,
  mtag_id         INT NOT NULL REFERENCES MTag_Account(mtag_id) ON DELETE CASCADE,
  amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  payment_channel VARCHAR(30) NOT NULL,
  transaction_ref VARCHAR(50) NOT NULL UNIQUE,
  paid_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status          VARCHAR(20) NOT NULL DEFAULT 'Success'
    CHECK (status IN ('Pending','Success','Failed'))
);

-- Junction: interchange pair + vehicle class -> fare
CREATE TABLE Toll_Tariff_Matrix (
  tariff_id            SERIAL PRIMARY KEY,
  entry_interchange_id INT NOT NULL REFERENCES Interchange(interchange_id),
  exit_interchange_id  INT NOT NULL REFERENCES Interchange(interchange_id),
  vclass_id            INT NOT NULL REFERENCES Vehicle_Class(vclass_id),
  distance_km          NUMERIC(6,2) NOT NULL CHECK (distance_km > 0),
  standard_toll_amount NUMERIC(8,2) NOT NULL CHECK (standard_toll_amount >= 0),
  peak_surcharge       NUMERIC(8,2) NOT NULL DEFAULT 0,
  CHECK (entry_interchange_id <> exit_interchange_id),
  UNIQUE (entry_interchange_id, exit_interchange_id, vclass_id)
);

CREATE TABLE Toll_Transit_Trip (
  trip_id                SERIAL PRIMARY KEY,
  mtag_id                INT NOT NULL REFERENCES MTag_Account(mtag_id),
  entry_lane_id          INT NOT NULL REFERENCES Toll_Lane(lane_id),
  exit_lane_id           INT REFERENCES Toll_Lane(lane_id),      -- NULL until vehicle exits
  entry_time             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  exit_time              TIMESTAMPTZ,
  computed_avg_speed_kmh NUMERIC(5,1),                            -- filled by trigger (Day 3)
  toll_deducted          NUMERIC(8,2) NOT NULL DEFAULT 0,
  trip_status            VARCHAR(20) NOT NULL DEFAULT 'In Transit'
    CHECK (trip_status IN ('In Transit','Completed','Violation','Cancelled')),
  CHECK (exit_time IS NULL OR exit_time > entry_time)
);

-- ============ MODULE 3: Enforcement ============

CREATE TABLE Weighbridge_Station (
  wb_id                SERIAL PRIMARY KEY,
  interchange_id       INT NOT NULL REFERENCES Interchange(interchange_id) ON DELETE CASCADE,
  station_code         VARCHAR(25) NOT NULL UNIQUE,
  max_scale_tons       NUMERIC(5,1) NOT NULL CHECK (max_scale_tons > 0),
  calibration_due_date DATE,
  status               VARCHAR(20) NOT NULL DEFAULT 'Active'
);

CREATE TABLE Axle_Weight_Log (
  weight_log_id      SERIAL PRIMARY KEY,
  wb_id              INT NOT NULL REFERENCES Weighbridge_Station(wb_id),
  vehicle_id         INT NOT NULL REFERENCES Registered_Vehicle(vehicle_id),
  measured_weight_kg INT NOT NULL CHECK (measured_weight_kg > 0),
  overload_kg        INT NOT NULL DEFAULT 0 CHECK (overload_kg >= 0),
  weighed_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  action_taken       VARCHAR(60)
);

CREATE TABLE ANPR_Speed_Camera (
  camera_id          SERIAL PRIMARY KEY,
  sector_id          INT NOT NULL REFERENCES Motorway_Sector(sector_id) ON DELETE CASCADE,
  km_marker          INT NOT NULL,
  direction          VARCHAR(15) NOT NULL,
  radar_limit_kmh    INT NOT NULL CHECK (radar_limit_kmh > 0),
  last_calibrated_on DATE,
  status             VARCHAR(20) NOT NULL DEFAULT 'Active'
);

-- ============ MODULE 4: Patrol officers (needed before challans) ============

CREATE TABLE Officer_Rank (
  rank_id           SERIAL PRIMARY KEY,
  rank_code         VARCHAR(15) NOT NULL UNIQUE,
  title             VARCHAR(60) NOT NULL,
  pay_scale         VARCHAR(15),
  command_authority VARCHAR(60)
);

CREATE TABLE Patrol_Officer (
  officer_id     SERIAL PRIMARY KEY,
  rank_id        INT NOT NULL REFERENCES Officer_Rank(rank_id),
  base_sector_id INT NOT NULL REFERENCES Motorway_Sector(sector_id),
  badge_no       VARCHAR(25) NOT NULL UNIQUE,
  first_name     VARCHAR(50) NOT NULL,
  last_name      VARCHAR(50) NOT NULL,
  phone          VARCHAR(20),
  hire_date      DATE,
  duty_status    VARCHAR(20) NOT NULL DEFAULT 'Active'
);

CREATE TABLE E_Challan_Ticket (
  challan_id         SERIAL PRIMARY KEY,
  vehicle_id         INT NOT NULL REFERENCES Registered_Vehicle(vehicle_id),
  camera_id          INT REFERENCES ANPR_Speed_Camera(camera_id),   -- NULL if officer-issued
  trip_id            INT REFERENCES Toll_Transit_Trip(trip_id),     -- set for average-speed challans
  officer_id         INT REFERENCES Patrol_Officer(officer_id),     -- NULL if automated
  violation_type     VARCHAR(40) NOT NULL,
  recorded_speed_kmh NUMERIC(5,1),
  fine_amount        NUMERIC(8,2) NOT NULL CHECK (fine_amount >= 0),
  demerit_added      INT NOT NULL DEFAULT 0 CHECK (demerit_added >= 0),
  issued_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payment_status     VARCHAR(20) NOT NULL DEFAULT 'Unpaid'
    CHECK (payment_status IN ('Unpaid','Paid','Disputed','Waived'))
);

CREATE TABLE Blacklisted_Vehicle_Alert (
  alert_id            SERIAL PRIMARY KEY,
  vehicle_id          INT NOT NULL REFERENCES Registered_Vehicle(vehicle_id),
  watch_reason        VARCHAR(100) NOT NULL,
  fir_reference       VARCHAR(50),
  flagged_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  intercepted_lane_id INT REFERENCES Toll_Lane(lane_id),            -- NULL until detected
  alert_status        VARCHAR(25) NOT NULL DEFAULT 'Active'
);

-- ============ MODULE 5: Road monitoring ============

CREATE TABLE Weather_Visibility_Sensor (
  sensor_id           SERIAL PRIMARY KEY,
  sector_id           INT NOT NULL REFERENCES Motorway_Sector(sector_id) ON DELETE CASCADE,
  km_marker           INT NOT NULL,
  visibility_meters   INT NOT NULL CHECK (visibility_meters >= 0),
  fog_density_pct     NUMERIC(5,2) CHECK (fog_density_pct BETWEEN 0 AND 100),
  road_surface_temp_c NUMERIC(4,1),
  wind_speed_kmh      INT,
  logged_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE Variable_Message_Sign (
  vms_id                 SERIAL PRIMARY KEY,
  sector_id              INT NOT NULL REFERENCES Motorway_Sector(sector_id) ON DELETE CASCADE,
  km_marker              INT NOT NULL,
  direction              VARCHAR(15) NOT NULL,
  displayed_message      VARCHAR(160),
  posted_speed_limit_kmh INT,
  last_updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  power_status           VARCHAR(20) NOT NULL DEFAULT 'On'
);

CREATE TABLE Service_Rest_Area (
  service_area_id     SERIAL PRIMARY KEY,
  sector_id           INT NOT NULL REFERENCES Motorway_Sector(sector_id) ON DELETE CASCADE,
  name                VARCHAR(80) NOT NULL,
  km_marker           INT NOT NULL,
  direction           VARCHAR(15) NOT NULL,
  parking_capacity    INT CHECK (parking_capacity >= 0),
  fuel_station_flag   BOOLEAN NOT NULL DEFAULT FALSE,
  trauma_center_flag  BOOLEAN NOT NULL DEFAULT FALSE
);

-- ============ MODULE 6: Patrol fleet & roster ============

CREATE TABLE Officer_Certification (
  cert_id          SERIAL PRIMARY KEY,
  officer_id       INT NOT NULL REFERENCES Patrol_Officer(officer_id) ON DELETE CASCADE,
  cert_type        VARCHAR(50) NOT NULL,
  training_academy VARCHAR(80),
  issued_date      DATE NOT NULL,
  expiry_date      DATE,
  CHECK (expiry_date IS NULL OR expiry_date > issued_date)
);

CREATE TABLE Patrol_Fleet_Unit (
  unit_id            SERIAL PRIMARY KEY,
  base_sector_id     INT NOT NULL REFERENCES Motorway_Sector(sector_id),
  call_sign          VARCHAR(30) NOT NULL UNIQUE,
  unit_type          VARCHAR(35) NOT NULL,
  reg_plate          VARCHAR(20) NOT NULL UNIQUE,
  odometer_km        INT NOT NULL DEFAULT 0 CHECK (odometer_km >= 0),
  gps_lat            DECIMAL(9,6),
  gps_lng            DECIMAL(9,6),
  operational_status VARCHAR(25) NOT NULL DEFAULT 'Available'
);

-- Junction: officer <-> unit
CREATE TABLE Patrol_Shift_Assignment (
  shift_id   SERIAL PRIMARY KEY,
  unit_id    INT NOT NULL REFERENCES Patrol_Fleet_Unit(unit_id),
  officer_id INT NOT NULL REFERENCES Patrol_Officer(officer_id),
  sector_id  INT NOT NULL REFERENCES Motorway_Sector(sector_id),
  shift_role VARCHAR(35) NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time   TIMESTAMPTZ NOT NULL,
  CHECK (end_time > start_time)
);

CREATE TABLE Fleet_Maintenance_Record (
  maint_id     SERIAL PRIMARY KEY,
  unit_id      INT NOT NULL REFERENCES Patrol_Fleet_Unit(unit_id) ON DELETE CASCADE,
  workshop_name VARCHAR(80),
  service_type VARCHAR(50) NOT NULL,
  performed_on DATE NOT NULL,
  next_due_km  INT NOT NULL,
  cost         NUMERIC(10,2) CHECK (cost >= 0)
);

CREATE TABLE Fleet_Fuel_Log (
  fuel_id          SERIAL PRIMARY KEY,
  unit_id          INT NOT NULL REFERENCES Patrol_Fleet_Unit(unit_id) ON DELETE CASCADE,
  shift_id         INT REFERENCES Patrol_Shift_Assignment(shift_id),
  liters_filled    NUMERIC(6,2) NOT NULL CHECK (liters_filled > 0),
  odometer_reading INT NOT NULL,
  fuel_cost        NUMERIC(8,2) NOT NULL CHECK (fuel_cost >= 0),
  logged_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============ MODULE 7: Incidents ============

CREATE TABLE Highway_Incident (
  incident_id   SERIAL PRIMARY KEY,
  sector_id     INT NOT NULL REFERENCES Motorway_Sector(sector_id),
  km_marker     INT NOT NULL,
  incident_type VARCHAR(40) NOT NULL,
  severity      VARCHAR(20) NOT NULL CHECK (severity IN ('Low','Medium','High','Critical')),
  lanes_blocked INT NOT NULL DEFAULT 0 CHECK (lanes_blocked >= 0),
  reported_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cleared_at    TIMESTAMPTZ,
  status        VARCHAR(20) NOT NULL DEFAULT 'Open'
    CHECK (status IN ('Open','Dispatched','Cleared')),
  CHECK (cleared_at IS NULL OR cleared_at >= reported_at)
);

-- Junction: incident <-> unit
CREATE TABLE Incident_Rescue_Dispatch (
  dispatch_id      SERIAL PRIMARY KEY,
  incident_id      INT NOT NULL REFERENCES Highway_Incident(incident_id) ON DELETE CASCADE,
  unit_id          INT NOT NULL REFERENCES Patrol_Fleet_Unit(unit_id),
  dispatched_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  arrived_at       TIMESTAMPTZ,
  response_mins    INT CHECK (response_mins >= 0),
  hospital_handoff VARCHAR(80),
  resolution_notes TEXT,
  CHECK (arrived_at IS NULL OR arrived_at >= dispatched_at)
);