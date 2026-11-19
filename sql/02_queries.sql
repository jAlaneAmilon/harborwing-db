USE harborwing;

-- Query 1: Reservation + passenger + agent + payments + legs
-- Dalawang separate subquery (payments, legs) para HINDI mag-inflate ang total
SELECT r.reservation_id,
       CONCAT(p.first_name, ' ', p.last_name) AS passenger,
       COALESCE(a.agent_name, 'Direct booking') AS agent,
       r.party_size,
       pay.payment_count,
       pay.total_paid,
       lg.leg_count,
       lg.legs
FROM reservation r
JOIN passenger p ON p.passenger_id = r.passenger_id
LEFT JOIN booking_agent a ON a.agent_id = r.agent_id
LEFT JOIN (
    SELECT rp.reservation_id,
           COUNT(*) AS payment_count,
           SUM(pm.payment_amount) AS total_paid
    FROM reservation_payment rp
    JOIN payment pm ON pm.payment_id = rp.payment_id
    GROUP BY rp.reservation_id
) pay ON pay.reservation_id = r.reservation_id
LEFT JOIN (
    SELECT rl.reservation_id,
           COUNT(*) AS leg_count,
           GROUP_CONCAT(CONCAT(l.flight_number, ' ', l.origin_airport, '->', l.destination_airport)
                        ORDER BY l.leg_id SEPARATOR ' | ') AS legs
    FROM reservation_leg rl
    JOIN flight_leg l ON l.leg_id = rl.leg_id
    GROUP BY rl.reservation_id
) lg ON lg.reservation_id = r.reservation_id
WHERE r.reservation_id = 1;

-- Query 2: Reservations na gumagamit ng isang leg
SELECT rl.leg_id, r.reservation_id, r.created_at, r.party_size,
       CONCAT(p.first_name, ' ', p.last_name) AS passenger
FROM reservation_leg rl
JOIN reservation r ON r.reservation_id = rl.reservation_id
JOIN passenger p ON p.passenger_id = r.passenger_id
WHERE rl.leg_id = 1;

-- Query 3: Payments na naka-link sa isang reservation
SELECT rp.reservation_id, pm.payment_id, pm.payment_status_code,
       pm.payment_date, pm.payment_amount
FROM reservation_payment rp
JOIN payment pm ON pm.payment_id = rp.payment_id
WHERE rp.reservation_id = 1;

-- Query 4: Flight cost para sa flight, aircraft type, at petsa
SET @flight = 'HW100';
SET @aircraft = (SELECT aircraft_type_code FROM flight_schedule WHERE flight_number = @flight);
SET @on_date = '2026-06-15';

SELECT flight_number, aircraft_type_code, valid_from, valid_to, cost_amount
FROM flight_cost
WHERE flight_number = @flight
  AND aircraft_type_code = @aircraft
  AND @on_date BETWEEN valid_from AND valid_to;