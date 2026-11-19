-- HarborWing Air schema (MySQL 8.0.16+, InnoDB)
-- WARNING: binubura nito ang existing na 'harborwing' database.
-- All timestamps are stored in UTC.
DROP DATABASE IF EXISTS harborwing;
CREATE DATABASE harborwing CHARACTER SET utf8mb4;
USE harborwing;

CREATE TABLE booking_agent (
  agent_id INT AUTO_INCREMENT PRIMARY KEY,
  agent_name VARCHAR(100) NOT NULL,
  agent_details VARCHAR(255) NULL
) ENGINE=InnoDB;

CREATE TABLE passenger (
  passenger_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  second_name VARCHAR(50) NULL,
  last_name VARCHAR(50) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(120) NOT NULL UNIQUE,
  address_line1 VARCHAR(120) NOT NULL,
  address_line2 VARCHAR(120) NULL,
  city VARCHAR(60) NOT NULL,
  state_province_county VARCHAR(60) NULL,
  country VARCHAR(60) NOT NULL,
  other_details VARCHAR(255) NULL,
  INDEX idx_passenger_name (last_name, first_name)
) ENGINE=InnoDB;

CREATE TABLE airport (
  airport_code CHAR(3) PRIMARY KEY,
  airport_name VARCHAR(100) NOT NULL,
  location VARCHAR(120) NOT NULL,
  other_details VARCHAR(255) NULL
) ENGINE=InnoDB;

CREATE TABLE calendar_date (
  cal_date DATE PRIMARY KEY,
  day_of_month TINYINT NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
  is_business_day BOOLEAN NOT NULL
) ENGINE=InnoDB;

CREATE TABLE payment (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  payment_status_code VARCHAR(10) NOT NULL COMMENT 'externally managed code',
  payment_date DATE NOT NULL,
  payment_amount DECIMAL(10,2) NOT NULL,
  CONSTRAINT chk_pay_amt CHECK (payment_amount > 0),
  INDEX idx_payment_date (payment_date)
) ENGINE=InnoDB;

CREATE TABLE flight_schedule (
  flight_number VARCHAR(10) PRIMARY KEY,
  airline_code CHAR(2) NOT NULL COMMENT 'externally managed',
  aircraft_type_code VARCHAR(10) NOT NULL COMMENT 'usual type; externally managed',
  origin_airport CHAR(3) NOT NULL,
  destination_airport CHAR(3) NOT NULL,
  sched_departure DATETIME NOT NULL COMMENT 'UTC',
  sched_arrival DATETIME NOT NULL COMMENT 'UTC',
  CONSTRAINT fk_fs_orig FOREIGN KEY (origin_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT fk_fs_dest FOREIGN KEY (destination_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT chk_fs_airports CHECK (origin_airport <> destination_airport),
  CONSTRAINT chk_fs_times CHECK (sched_arrival > sched_departure),
  INDEX idx_fs_route (origin_airport, destination_airport),
  INDEX idx_fs_dep (sched_departure)
) ENGINE=InnoDB;

CREATE TABLE flight_leg (
  leg_id INT AUTO_INCREMENT PRIMARY KEY,
  flight_number VARCHAR(10) NOT NULL,
  origin_airport CHAR(3) NOT NULL,
  destination_airport CHAR(3) NOT NULL,
  actual_departure DATETIME NULL COMMENT 'UTC; NULL until operated',
  actual_arrival DATETIME NULL COMMENT 'UTC; NULL until operated',
  CONSTRAINT fk_fl_fs FOREIGN KEY (flight_number) REFERENCES flight_schedule(flight_number) ON DELETE RESTRICT,
  CONSTRAINT fk_fl_orig FOREIGN KEY (origin_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT fk_fl_dest FOREIGN KEY (destination_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT chk_fl_airports CHECK (origin_airport <> destination_airport),
  CONSTRAINT chk_fl_times CHECK (actual_arrival IS NULL OR actual_departure IS NULL OR actual_arrival > actual_departure),
  INDEX idx_fl_flight (flight_number)
) ENGINE=InnoDB;

CREATE TABLE flight_cost (
  flight_number VARCHAR(10) NOT NULL,
  aircraft_type_code VARCHAR(10) NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE NOT NULL,
  cost_amount DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (flight_number, aircraft_type_code, valid_from),
  CONSTRAINT fk_fc_fs FOREIGN KEY (flight_number) REFERENCES flight_schedule(flight_number) ON DELETE RESTRICT,
  CONSTRAINT fk_fc_from FOREIGN KEY (valid_from) REFERENCES calendar_date(cal_date) ON DELETE RESTRICT,
  CONSTRAINT fk_fc_to FOREIGN KEY (valid_to) REFERENCES calendar_date(cal_date) ON DELETE RESTRICT,
  CONSTRAINT chk_fc_dates CHECK (valid_to >= valid_from),
  CONSTRAINT chk_fc_cost CHECK (cost_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE reservation (
  reservation_id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_id INT NOT NULL,
  agent_id INT NULL,
  reservation_status_code VARCHAR(10) NOT NULL COMMENT 'externally managed',
  ticket_type_code VARCHAR(10) NOT NULL COMMENT 'externally managed',
  travel_class_code VARCHAR(10) NOT NULL COMMENT 'externally managed',
  created_at DATETIME NOT NULL COMMENT 'UTC',
  party_size SMALLINT NOT NULL,
  CONSTRAINT fk_res_pax FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id) ON DELETE RESTRICT,
  CONSTRAINT fk_res_agent FOREIGN KEY (agent_id) REFERENCES booking_agent(agent_id) ON DELETE RESTRICT,
  CONSTRAINT chk_party CHECK (party_size > 0),
  INDEX idx_res_pax (passenger_id),
  INDEX idx_res_agent (agent_id),
  INDEX idx_res_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE reservation_payment (
  reservation_id INT NOT NULL,
  payment_id INT NOT NULL,
  PRIMARY KEY (reservation_id, payment_id),
  CONSTRAINT fk_rp_res FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id) ON DELETE CASCADE,
  CONSTRAINT fk_rp_pay FOREIGN KEY (payment_id) REFERENCES payment(payment_id) ON DELETE RESTRICT,
  INDEX idx_rp_pay (payment_id)
) ENGINE=InnoDB;

CREATE TABLE reservation_leg (
  reservation_id INT NOT NULL,
  leg_id INT NOT NULL,
  PRIMARY KEY (reservation_id, leg_id),
  CONSTRAINT fk_rl_res FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id) ON DELETE CASCADE,
  CONSTRAINT fk_rl_leg FOREIGN KEY (leg_id) REFERENCES flight_leg(leg_id) ON DELETE RESTRICT,
  INDEX idx_rl_leg (leg_id)
) ENGINE=InnoDB;