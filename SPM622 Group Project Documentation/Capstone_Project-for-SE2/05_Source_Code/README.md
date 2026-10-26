# SmartDesk — Source Code

## Project
- **Title:** SmartDesk: A Customer Support Ticketing System for Small IT Support Teams
- **Team:** Freek Schaefer-Gerber, Wian Sandenbergh (Group Fish)
- **Problem:** Small support teams receive fault reports via WhatsApp, email and
  verbal requests. Nothing is centrally recorded, so requests are lost or
  duplicated and there is no audit trail.
- **Solution:** A database-driven ticketing application with role-based access,
  ticket logging, staff assignment, status tracking, an attributable
  conversation per ticket, and a status dashboard.

## Technology Stack
| Layer | Technology |
|---|---|
| Presentation | Jinja2 templates, HTML5, CSS3 |
| Application | Python 3.11+, Flask 3 |
| Data access | `sqlite3` (stdlib), parameterised SQL |
| Runtime database | SQLite 3 |
| Coursework database artefact | Microsoft SQL Server 2022 (SSMS) — **not** used at runtime |
| Security | Werkzeug password hashing, session auth, CSRF tokens |
| Testing | pytest 8 |
| Version control | Git, GitHub |

## Setup
1. Clone the repository.
2. `py -m venv .venv` then `.venv\Scripts\Activate.ps1`
3. `pip install -r requirements.txt`
4. Copy `.env.example` to `.env` and set `SECRET_KEY`.
5. `$env:FLASK_APP="app.py"`
6. `flask init-db` then `flask seed-demo`
7. `python app.py` and open http://127.0.0.1:5000

## Database
- `sql/sqlite_schema.sql` — **runtime** schema (SQLite). Created by `flask init-db`.
- `sql/sqlserver_schema.sql` — **MDB622 coursework artefact** (SQL Server 2022).
  Run manually in SSMS. The application does **not** connect to SQL Server.

## Repository Expectations
Meaningful commit messages describing the change; feature branches merged to
`main`; both contributors commit regularly. No secrets, passwords or `.env`
files are committed.

## Demonstration
| Role | Email | Password |
|---|---|---|
| Admin | admin@smartdesk.local | DemoPass123! |
| Agent | agent@smartdesk.local | DemoPass123! |
| Customer | customer@smartdesk.local | DemoPass123! |

**Local demonstration only.** Change or delete these before any deployment.

**Feature sequence:** log in as customer → create ticket → log in as agent →
assign and update status → add comment → return to customer and view thread →
check dashboard counts → verify a second customer cannot open the first
customer's ticket (403).

## Tests
`pytest -q` — three automated tests covering registration/ticket/comment,
login and access control, and customer isolation.