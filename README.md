# HarborWing Air: Reservation Database

**Author:** (Jalane, Amilon A., BSIT3B2)
**Course:** IT8, Midterm Drill

A relational MySQL database that replaces HarborWing Air's spreadsheets.
It stores passengers, booking agents, reservations, payments, airports, flight schedules, flight legs, a calendar, and flight-cost history.

## Folder structure

```
harborwing/
├─ diagram/   harborwing.mwb (MySQL Workbench model), harborwing.png (EER diagram)
├─ sql/       01_schema.sql, 02_queries.sql, 03_rowcounts.sql
├─ seed/      seed.py, requirements.txt
└─ README.md
```

## Requirements

- MySQL Server 8.0.16 or newer (needed so `CHECK` constraints are enforced)
- MySQL Workbench 8.0
- Python 3.9+
- Python packages in `seed/requirements.txt` (Faker, mysql-connector-python)

## Setup: create, seed, query

1. **Create the schema.** Open `sql/01_schema.sql` in MySQL Workbench and run it (lightning bolt),
   or from a terminal: `mysql -u root -p < sql/01_schema.sql`
2. **Install dependencies.**
   ```
   cd seed
   pip install -r requirements.txt
   ```
3. **Seed the data.**
   ```
   python seed.py
   ```
   The script asks for the MySQL root password (or reads the `DB_PASSWORD` environment variable).
   The password is never stored in the code. It connects to `localhost`, user `root`, database `harborwing`.
   If your setup differs, edit the connection values at the top of `seed.py`.
4. **Verify row counts.** Run `sql/03_rowcounts.sql`. Every table has at least 50 rows.
5. **Run the example queries.** Open `sql/02_queries.sql` and run one query at a time.

### Reset process

To get back to a clean, identical database at any time:

1. Re-run `sql/01_schema.sql` (drops and recreates the `harborwing` database), then
2. Re-run `python seed.py`.

`seed.py` also truncates all 11 tables before inserting, so running it alone also resets the data.
The generator uses a fixed seed (`SEED = 42` for both `random` and Faker), so every run produces the same data.

## Tables and their purpose

| Table | Purpose |
|---|---|
| `booking_agent` | Agents who book on behalf of customers |
| `passenger` | One row per customer (name, contact, address) |
| `reservation` | One booking: main passenger, optional agent, status/ticket/class codes, creation time, party size |
| `payment` | One payment: status, date, amount |
| `airport` | Airport code, name, location |
| `flight_schedule` | A planned flight: flight number, route, scheduled departure/arrival |
| `flight_leg` | One operated flight leg of a schedule, with actual departure/arrival |
| `calendar_date` | One row per date (day of month, business-day flag) |
| `flight_cost` | Cost of a flight and aircraft type, valid for a date range |
| `reservation_payment` | Link table: reservations <-> payments |
| `reservation_leg` | Link table: reservations <-> flight legs |

## How the tables relate

- `passenger` 1 --- N `reservation` (every reservation has exactly one main passenger).
- `booking_agent` 1 --- N `reservation` (the agent is optional: `agent_id` is `NULL` for direct bookings).
- `reservation` N --- M `payment` through `reservation_payment`.
- `reservation` N --- M `flight_leg` through `reservation_leg`.
- `flight_schedule` 1 --- N `flight_leg`.
- `airport` 1 --- N `flight_schedule` and `flight_leg` (twice each: origin and destination).
- `flight_schedule` 1 --- N `flight_cost`.
- `calendar_date` 1 --- N `flight_cost` (twice: `valid_from` and `valid_to`).

## Why two linking tables are necessary

A reservation can have many payments, and one payment can cover many reservations (many-to-many).
A reservation can include many legs (connecting flights), and one leg is used by many reservations.
A single foreign-key column cannot store a many-to-many relationship.
Each link table holds one row per connection, and its composite primary key
(`reservation_id`, `payment_id` or `leg_id`) prevents duplicate pairs.

## Why scheduled and actual times are separate

`flight_schedule` stores the planned times. `flight_leg` stores the actual times, which are `NULL` until the flight operates.
Keeping them apart means the actual time can never overwrite the plan (a problem in the old spreadsheets),
and delays can be measured by comparing the two.
All timestamps are stored in **UTC**.

## Why flight costs use a composite key

The primary key of `flight_cost` is (`flight_number`, `aircraft_type_code`, `valid_from`).
The same flight and aircraft type can have many cost rows over time, each starting on a different date.
Adding a new cost row keeps the old ones, so the price history is preserved (the old spreadsheets lost it on every update).
Both `valid_from` and `valid_to` reference `calendar_date`.

## Constraints, indexes, and deletion rules

- **Engine:** InnoDB for every table (foreign keys and transactions).
- **Validation (`CHECK`):** party size > 0; payment amount > 0; cost >= 0; `valid_to >= valid_from`;
  origin <> destination (schedule and leg); scheduled arrival > departure; actual arrival > actual departure when both are known.
- **Unique:** `passenger.email`; all primary keys; composite keys on both link tables and `flight_cost`.
- **Indexes:** passenger name; payment date; schedule route and departure time; leg by flight number;
  reservation by passenger, agent, and creation time; reverse-direction indexes on both link tables.

| Relationship | On delete | Reason |
|---|---|---|
| reservation -> passenger | RESTRICT | Keep booking history |
| reservation -> booking_agent | RESTRICT | Keep booking history. An agent with reservations cannot be deleted. |
| flight_schedule / flight_leg -> airport | RESTRICT | An airport in use cannot be deleted |
| flight_leg, flight_cost -> flight_schedule | RESTRICT | Keep operational and cost history |
| flight_cost -> calendar_date | RESTRICT | Dates in use cannot be deleted |
| link tables -> reservation | CASCADE | A link row means nothing without its reservation |
| link tables -> payment / flight_leg | RESTRICT | Linked payments and legs cannot be deleted |

## Reference codes

Status, ticket type, travel class, airline, and aircraft type are **externally managed codes**.
They are stored as plain columns (with a `COMMENT`) and have **no foreign keys**, because no local reference tables exist.
Demo values in the generated data: payment status `PAID/PEND/REFD`, reservation status `CONF/PEND/CANC`,
ticket type `ONEWAY/RETURN`, class `ECON/BUS/FIRST`, aircraft `AT72/DH8D/E175/A320`, airline `HW`.
These are demonstration data. Airport codes are random fictional three-letter codes.

## Simplifying assumption: flight number

`flight_number` is treated as a unique schedule identifier.
A production airline system would need a more detailed identifier, because a real flight number such as "HW101"
is reused every day (and sometimes by different routes or aircraft). It would need something like
flight number + operating date, or a separate schedule-instance ID, so each operation of a flight is uniquely identified.

## Synthetic data

`seed/seed.py` uses Python Faker with a fixed seed. Everything is fictional. Rows are inserted parents first, then children.
Link-table pairs are built from Python `set`s, so no duplicates occur. The data includes:

- Direct reservations (about 40%, `agent_id = NULL`) and agent-assisted reservations
- Reservations with several payments and several legs
- Payments shared by several reservations
- Flights with 2 or 3 different, non-overlapping cost validity periods
- Legs that have not operated yet (`NULL` actual times)

## Example queries (`sql/02_queries.sql`)

1. A reservation with its passenger, agent, payments, and legs. Payments and legs are aggregated in **separate subqueries**
   before joining. Joining both directly would multiply rows (3 payments x 4 legs = 12 rows) and inflate `SUM(payment_amount)`.
2. Reservations that use a particular leg.
3. Payments linked to a reservation.
4. The cost of a flight and aircraft type on a given date (`date BETWEEN valid_from AND valid_to`).

## Advantages and trade-offs

**Advantages:** no repeated passenger data; consistent airport names (one row each, referenced by code);
legs are trackable per reservation; payments are never duplicated; actual and scheduled times are separate;
cost history is preserved; constraints reject bad data at the database level.

**Trade-offs:** more tables means more joins; link tables add complexity to queries;
constraints and foreign keys make bulk loading stricter (parents must exist first).

## Limitations

- **Shared payments:** the link table does not store an allocation amount, so when one payment covers several reservations
  the database cannot say how much belongs to each reservation.
- **Party size:** only the main passenger and a party-size number are stored, so individual travelers are not identified.
- **Joins:** separating data reduces duplication, but queries need joins, and careless joins (payments x legs) can inflate totals.
- **Overlapping cost periods:** the primary key only prevents two rows with the same `valid_from`.
  It does not stop overlapping date ranges for the same flight and aircraft type.
  A policy is needed (for example, the application or a trigger rejects overlaps, or the row with the latest `valid_from` wins).
  The seed data creates non-overlapping periods only.