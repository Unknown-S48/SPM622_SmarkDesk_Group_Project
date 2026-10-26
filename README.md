# SmartDesk — Customer Support Ticketing System

**Capstone team:** Freek Schaefer-Gerber and Wian Sandenbergh  
**Lecturer:** Dunstan  
**Submission deadline:** 29 October 2026

A working, local-first customer support web app with secure password hashing, customer registration/login, tickets, statuses, priorities, comments, role-restricted management and a dashboard.

## Run on Windows (PowerShell)

1. Install **Python 3.11 or newer** from python.org and enable *Add Python to PATH*.
2. Extract the ZIP and open a terminal in the `customer_support_app` folder.
3. Run:

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:FLASK_APP="app.py"
flask init-db
flask seed-demo
python app.py
```

4. Open **http://127.0.0.1:5000** in your browser.

### Demo accounts (local demonstration ONLY)

| Role | Email | Password |
|---|---|---|
| Admin | admin@smartdesk.local | DemoPass123! |
| Support agent | agent@smartdesk.local | DemoPass123! |
| Customer | customer@smartdesk.local | DemoPass123! |

**Never use these demo credentials in a publicly deployed application.** Delete the `support.db` file and run `flask init-db` to start with a blank database. For production, set a strong `SECRET_KEY`, use HTTPS, and add rate limiting, account recovery, audit logging and a production-grade WSGI server.

## Main workflows

1. Sign in as customer; create a ticket with category and priority.
2. Sign in as support agent; open ticket, assign it to an agent, update priority and status.
3. Reply in the ticket conversation from either account.
4. View ticket counts and progress in the dashboard.
5. Register another customer; verify they cannot see the first customer's tickets.

## Database scripts

- `sql/sqlite_schema.sql`: **actual running application** database, created by `flask init-db`. No database server required.
- `sql/sqlserver_schema.sql`: **separate Microsoft SQL Server schema** for SSMS/SQL Server coursework. This is an equivalent design, but **the Flask app does not connect to SQL Server**. Do not claim otherwise in the dissertation. Migrating the app to SQL Server requires changing the database connection and SQL queries.

## Automated tests

```powershell
pytest -q
```

## Suggested evidence for the dissertation

- Screenshot: registration/login
- Screenshot: customer dashboard
- Screenshot: new ticket form
- Screenshot: ticket details and comments
- Screenshot: agent assignment and status update
- Screenshot: SQL Server schema created in SSMS (if you execute the script)
- Screenshot: `pytest -q` output
- Screenshot: GitHub commit history for both contributors

## Project structure

```
app.py                 Flask routes, permissions and database access
requirements.txt       Python dependencies
sql/sqlite_schema.sql  Runtime SQLite schema
sql/sqlserver_schema.sql  Separate SQL Server coursework schema
templates/             HTML pages
static/style.css       Responsive design
tests/test_app.py       Automated tests
```

## Scope and limitations

This is an **MVP**, not a production helpdesk. It has no email notifications, file attachments, SLA timers, password reset, audit trail, or advanced analytics. It uses SQLite for the runnable demo; the SQL Server script is supplied for database-design assessment. The local demo uses a development-only secret by default. Record only real execution screenshots and test results in Chapter 5.
