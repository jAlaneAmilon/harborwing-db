import os
import getpass
import random
import string
from datetime import date, datetime, timedelta

import mysql.connector
from faker import Faker

# ---------- Config ----------
SEED = 42
random.seed(SEED)
Faker.seed(SEED)
fake = Faker()

DB_PASSWORD = os.environ.get("DB_PASSWORD") or getpass.getpass("MySQL root password: ")
conn = mysql.connector.connect(host="localhost", user="root",
                               password=DB_PASSWORD, database="harborwing")
cur = conn.cursor()

TABLES = ["booking_agent", "passenger", "airport", "calendar_date", "payment",
          "flight_schedule", "flight_leg", "flight_cost", "reservation",
          "reservation_payment", "reservation_leg"]

def rand_dt(start, end):
    return start + timedelta(seconds=random.randint(0, int((end - start).total_seconds())))

# ---------- RESET (para repeatable) ----------
cur.execute("SET FOREIGN_KEY_CHECKS=0")
for t in TABLES:
    cur.execute(f"TRUNCATE TABLE {t}")
cur.execute("SET FOREIGN_KEY_CHECKS=1")

# ---------- 1. airport (60) ----------
codes = set()
while len(codes) < 60:
    codes.add("".join(random.choices(string.ascii_uppercase, k=3)))
codes = sorted(codes)
airports = [(c, f"{fake.city()} Demo Airport", f"{fake.city()}, {fake.country()}", None)
            for c in codes]
cur.executemany("INSERT INTO airport VALUES (%s,%s,%s,%s)", airports)

# ---------- 2. booking_agent (60) ----------
agents = [(fake.company(), fake.catch_phrase()) for _ in range(60)]
cur.executemany("INSERT INTO booking_agent (agent_name, agent_details) VALUES (%s,%s)", agents)

# ---------- 3. passenger (120) ----------
passengers = []
for _ in range(120):
    passengers.append((
        fake.first_name(),
        fake.first_name() if random.random() < 0.4 else None,
        fake.last_name(),
        fake.phone_number()[:30],
        fake.unique.email(),
        fake.street_address(),
        fake.secondary_address() if random.random() < 0.3 else None,
        fake.city(),
        fake.state() if random.random() < 0.8 else None,
        fake.country(),
        None,
    ))
cur.executemany("""INSERT INTO passenger (first_name, second_name, last_name, phone, email,
    address_line1, address_line2, city, state_province_county, country, other_details)
    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""", passengers)

# ---------- 4. calendar_date (730 days: 2026-01-01 to 2027-12-31) ----------
cal_start = date(2026, 1, 1)
calendar = []
for i in range(730):
    d = cal_start + timedelta(days=i)
    calendar.append((d, d.day, d.weekday() < 5))
cur.executemany("INSERT INTO calendar_date VALUES (%s,%s,%s)", calendar)

# ---------- 5. payment (100) ----------
payments = []
for _ in range(100):
    payments.append((
        random.choice(["PAID", "PEND", "REFD"]),
        cal_start + timedelta(days=random.randint(0, 729)),
        round(random.uniform(50, 900), 2),
    ))
cur.executemany("""INSERT INTO payment (payment_status_code, payment_date, payment_amount)
                   VALUES (%s,%s,%s)""", payments)

# ---------- 6. flight_schedule (60) ----------
aircraft_types = ["AT72", "DH8D", "E175", "A320"]
schedules = []
for n in range(100, 160):
    o, d = random.sample(codes, 2)
    dep = rand_dt(datetime(2026, 1, 1), datetime(2027, 11, 30))
    arr = dep + timedelta(minutes=random.randint(60, 300))
    schedules.append(("HW" + str(n), "HW", random.choice(aircraft_types), o, d, dep, arr))
cur.executemany("INSERT INTO flight_schedule VALUES (%s,%s,%s,%s,%s,%s,%s)", schedules)

# ---------- 7. flight_leg (120) ----------
legs = []
for i in range(120):
    s = schedules[i] if i < 60 else random.choice(schedules)
    if random.random() < 0.7:  # operated na
        dd = random.randint(-5, 40)
        da = dd + random.randint(-10, 20)
        a_dep = s[5] + timedelta(minutes=dd)
        a_arr = s[6] + timedelta(minutes=da)
    else:                      # hindi pa operated
        a_dep = a_arr = None
    legs.append((s[0], s[3], s[4], a_dep, a_arr))
cur.executemany("""INSERT INTO flight_leg (flight_number, origin_airport, destination_airport,
                   actual_departure, actual_arrival) VALUES (%s,%s,%s,%s,%s)""", legs)

# ---------- 8. flight_cost (2-3 non-overlapping periods per schedule) ----------
costs = []
for s in schedules:
    n = random.choice([2, 3])
    length = 730 // n
    base = random.uniform(8000, 40000)
    for i in range(n):
        vf = cal_start + timedelta(days=i * length)
        vt = vf + timedelta(days=length - 1)
        costs.append((s[0], s[2], vf, vt, round(base * (1 + 0.05 * i), 2)))
cur.executemany("INSERT INTO flight_cost VALUES (%s,%s,%s,%s,%s)", costs)

# ---------- 9. reservation (120, ~40% direct) ----------
reservations = []
for _ in range(120):
    agent = None if random.random() < 0.4 else random.randint(1, 60)
    reservations.append((
        random.randint(1, 120),
        agent,
        random.choice(["CONF", "PEND", "CANC"]),
        random.choice(["ONEWAY", "RETURN"]),
        random.choice(["ECON", "ECON", "BUS", "FIRST"]),
        rand_dt(datetime(2026, 1, 1), datetime(2027, 6, 30)),
        random.choice([1, 1, 2, 2, 3, 4, 5, 6]),
    ))
cur.executemany("""INSERT INTO reservation (passenger_id, agent_id, reservation_status_code,
    ticket_type_code, travel_class_code, created_at, party_size)
    VALUES (%s,%s,%s,%s,%s,%s,%s)""", reservations)

# ---------- 10. reservation_payment ----------
rp = set()
for r in range(1, 121):
    for p in random.sample(range(1, 101), random.choice([1, 1, 1, 2, 3, 4])):
        rp.add((r, p))
cur.executemany("INSERT INTO reservation_payment VALUES (%s,%s)", sorted(rp))

# ---------- 11. reservation_leg ----------
rl = set()
for r in range(1, 121):
    for l in random.sample(range(1, 121), random.choice([1, 1, 2, 2, 3, 4])):
        rl.add((r, l))
cur.executemany("INSERT INTO reservation_leg VALUES (%s,%s)", sorted(rl))

conn.commit()

# ---------- Row counts ----------
print("Done! Row counts:")
for t in TABLES:
    cur.execute(f"SELECT COUNT(*) FROM {t}")
    print(f"  {t}: {cur.fetchone()[0]}")

cur.close()
conn.close()