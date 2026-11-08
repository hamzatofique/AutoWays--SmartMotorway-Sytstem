
# AutoWays: Smart Motorway, M-Tag Toll & Patrol Operations

A smart motorway operations system built on a **29-table PostgreSQL database**. It manages RFID M-Tag tolling, ANPR speed enforcement, cargo weighbridges, highway patrol fleets and emergency incident dispatch, modeled on real Intelligent Transportation Systems such as Pakistan's M-1 / M-2 motorway network.

> University Database Systems course project.
> **Group member:** Hamza Toufeeque | **Roll No:** BCSF25M529

---

## Live Demo

| Layer | Link |
|---|---|
| Frontend (Vercel) | _coming soon_ |
| Backend API (Render) | _coming soon_ |
| Database (Neon) | _coming soon_ |

---

## Features

- **M-Tag Toll & Transit:** wallet top-ups, entry/exit lane scans, distance-based fare deduction
- **ANPR E-Challan & Weighbridge:** automatic speeding challans, overloaded truck detection
- **Patrol Roster & Fleet:** officer shifts, certifications, fuel and maintenance tracking
- **Incident & Fog Control:** accident and closure logging, nearest-unit rescue dispatch
- **Road Monitoring:** weather/visibility sensors, variable message signs, service areas
- **Blacklisted Vehicle Alerts:** watch-list flagging when a vehicle is detected at a toll lane
- **Motorist Portal:** trip statements, pay pending challans, live sector status
- **Four role-based portals:** Motorist, Toll Supervisor, Patrol Dispatcher, Highway Admin

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | React, HTML, CSS, JavaScript | M-Tag portal, toll gate simulator, live VMS fog board, dispatch dashboard |
| Charts | Chart.js (react-chartjs-2) | Hourly traffic flow, toll vs. challan revenue, fog visibility trends |
| Backend | Node.js, Express.js, REST APIs | Handles requests and RFID/IoT scans, auth middleware |
| DB access | node-postgres (`pg` Pool) | Parameterized raw SQL, stored functions, ACID transactions |
| Database | PostgreSQL on Neon | 29 tables, PL/pgSQL triggers, functions, views, indexes |
| Auth | JWT / Express sessions with roles | Role-based access to API endpoints |
| Hosting | Git, GitHub, Vercel, Render, Neon | Free-tier live deployment |

---

## System Architecture

```
Users (Motorist / Toll Supervisor / Patrol Dispatcher / Admin)
        |
        v   HTTPS
React Frontend (Vercel)
        |
        v   JSON
Node.js + Express REST API (Render)
        |
        v   SQL (pg Pool)
PostgreSQL (Neon): 29 tables, triggers, functions, views, indexes
```

The browser never talks to PostgreSQL directly. Every scan, challan query and dispatch goes through the Express API.

---

## Database Design

**29 tables** across 7 groups:

| Group | Tables |
|---|---|
| Network | Motorway_Corridor, Motorway_Sector, Interchange, Toll_Plaza, Toll_Lane |
| Vehicles & Toll | Vehicle_Class, Motorist, Registered_Vehicle, MTag_Account, MTag_Topup_Payment, Toll_Tariff_Matrix, Toll_Transit_Trip |
| Enforcement | Weighbridge_Station, Axle_Weight_Log, ANPR_Speed_Camera, E_Challan_Ticket, Blacklisted_Vehicle_Alert |
| Road Monitoring | Weather_Visibility_Sensor, Variable_Message_Sign, Service_Rest_Area |
| Officers | Officer_Rank, Patrol_Officer, Officer_Certification |
| Fleet | Patrol_Fleet_Unit, Patrol_Shift_Assignment, Fleet_Maintenance_Record, Fleet_Fuel_Log |
| Incidents | Highway_Incident, Incident_Rescue_Dispatch |

**Junction tables (many-to-many):** `Toll_Tariff_Matrix`, `Patrol_Shift_Assignment`, `Incident_Rescue_Dispatch`

ER diagram: see [`docs/erd.png`](docs/erd.png)

### Database features demonstrated

- **Triggers**
  - Auto-calculate average speed on trip exit; if above the limit, auto-issue an `E_Challan_Ticket` and add demerit points
  - Block or fine an `Axle_Weight_Log` entry when weight exceeds the vehicle class limit
  - Block assigning a patrol unit to a shift if it is overdue for maintenance
- **Stored functions:** look up the toll fare from `Toll_Tariff_Matrix` and deduct from `MTag_Account.wallet_balance` atomically
- **Views:** Motorway Fog & Closure Advisory Board, Unpaid E-Challan Blacklist, Sector Patrol Duty Roster
- **Transactions & locking:** `SELECT ... FOR UPDATE` to prevent two operators dispatching the same unit at once
- **Indexes:** composite B-Tree on `Toll_Transit_Trip(mtag_id, entry_time DESC)` and `Registered_Vehicle(plate_no)`, benchmarked with `EXPLAIN ANALYZE`
- **Role-based access:** SQL `GRANT` / `REVOKE` for Motorists, Toll Supervisors and Patrol Commanders

---

## Project Structure

```
autoways/
├── backend/
│   ├── src/
│   │   ├── config/db.js        # pg Pool connection
│   │   └── server.js           # Express entry point
│   ├── sql/
│   │   └── schema.sql          # 29-table schema
│   ├── .env                    # not committed
│   └── package.json
├── frontend/                   # React app
├── docs/
│   └── erd.png
└── README.md
```

---

## Getting Started

### Prerequisites
- Node.js 18+
- A free [Neon](https://neon.tech) PostgreSQL project
- Git

### 1. Clone
```bash
git clone https://github.com/<your-username>/autoways.git
cd autoways
```

### 2. Database
1. Create a Neon project and copy the connection string.
2. Open the Neon SQL Editor, paste `backend/sql/schema.sql` and run it.
3. Verify:
```sql
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
-- expected: 29
```

> **Warning:** `schema.sql` begins with `DROP SCHEMA public CASCADE`, which deletes all existing data. Remove that line once you have real data.

### 3. Backend
```bash
cd backend
npm install
```
Create `backend/.env`:
```
DATABASE_URL=postgresql://user:password@host/dbname?sslmode=require
PORT=5000
```
Run:
```bash
npm run dev
```
Check `http://localhost:5000/api/health`. It should return `{"status":"ok","db_time":"..."}`.

### 4. Frontend
```bash
cd frontend
npm install
npm start
```

---

## Roadmap

- [x] Day 1: Project setup, Express server, Neon connection
- [x] Day 2: Full 29-table schema
- [ ] Day 3: Triggers and stored functions
- [ ] Day 4: Views, indexes, sample data
- [ ] Day 5: Authentication (JWT + roles), GRANT/REVOKE
- [ ] Day 6: REST APIs for all modules
- [ ] Day 7: React frontend and Chart.js dashboards
- [ ] Day 8: Deployment, EXPLAIN ANALYZE report, final docs

---

## Deliverables

- ER diagram and 3NF normalization notes
- SQL scripts: schema, constraints, triggers, functions, views, sample data
- Node.js / Express REST API
- React frontend with M-Tag top-up, toll simulator, e-challan portal and dispatch dashboard
- Live links for database, backend and frontend
- Screenshots and `EXPLAIN ANALYZE` benchmark report

---

## License

Built for academic purposes