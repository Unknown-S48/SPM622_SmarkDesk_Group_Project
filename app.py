import os
import sqlite3
import secrets
from datetime import datetime, timezone
from functools import wraps
from pathlib import Path

from flask import Flask, render_template, request, redirect, url_for, flash, session, abort, g
from werkzeug.security import generate_password_hash, check_password_hash

# =====================================================================
# 1. APPLICATION SETUP & CONFIGURATION
# =====================================================================
BASE = Path(__file__).resolve().parent
app = Flask(__name__)

# Security: The secret key is required for session management and CSRF tokens.
# It pulls from the environment, falling back to a dev key ONLY for local testing.
app.secret_key = os.environ.get('SECRET_KEY', 'development-only-change-this-key')

# Database path configuration
app.config['DATABASE'] = os.environ.get('DATABASE_PATH', str(BASE / 'support.db'))

# Allowed ENUM values (Must match the CHECK constraints in the SQLite schema)
STATUSES = ('Open', 'In Progress', 'Pending', 'Resolved', 'Closed')
PRIORITIES = ('Low', 'Medium', 'High', 'Critical')
CATEGORIES = ('Account', 'Billing', 'Technical', 'Product', 'General')


# =====================================================================
# 2. DATABASE CONNECTION HELPERS
# =====================================================================
def db():
    """Establishes a database connection using Flask's application context."""
    if 'db' not in g:
        g.db = sqlite3.connect(app.config['DATABASE'])
        g.db.row_factory = sqlite3.Row  # Allows accessing columns by name like a dictionary
        # CRITICAL: SQLite ignores foreign keys by default. This enforces referential integrity.
        g.db.execute('PRAGMA foreign_keys=ON')
    return g.db

@app.teardown_appcontext
def close_db(exc):
    """Closes the database connection at the end of each request."""
    conn = g.pop('db', None)
    if conn:
        conn.close()

def init_db():
    """Executes the schema.sql file to build the tables."""
    with app.app_context():
        db().executescript((BASE / 'sql' / 'sqlite_schema.sql').read_text())
        db().commit()


# =====================================================================
# 3. UTILITY & SECURITY HELPERS
# =====================================================================
def now():
    """Returns the current UTC timestamp in a standard SQLite-friendly format."""
    return datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')

def current_user():
    """Retrieves the currently logged-in user from the session."""
    if 'user_id' not in session:
        return None
    return db().execute('SELECT id, name, email, role FROM users WHERE id=?', (session['user_id'],)).fetchone()

def login_required(fn):
    """Decorator that redirects unauthenticated users to the login page."""
    @wraps(fn)
    def inner(*args, **kwargs):
        if not current_user():
            return redirect(url_for('login'))
        return fn(*args, **kwargs)
    return inner

def csrf_token():
    """Generates a unique CSRF token and stores it in the session."""
    if '_csrf' not in session:
        session['_csrf'] = secrets.token_hex(24)
    return session['_csrf']

# Make the CSRF token and current_user available to all Jinja2 templates
app.jinja_env.globals['csrf_token'] = csrf_token
app.jinja_env.globals['current_user'] = current_user

@app.before_request
def protect_forms():
    """Security Middleware: Rejects any POST request that lacks a valid CSRF token."""
    if request.method == 'POST':
        token = str(session.get('_csrf', ''))
        form_token = str(request.form.get('_csrf', ''))
        # Use secrets.compare_digest to prevent timing attacks
        if not secrets.compare_digest(token, form_token):
            abort(400, 'Invalid CSRF token. Refresh the page and try again.')


# =====================================================================
# 4. AUTHENTICATION ROUTES
# =====================================================================
@app.route('/')
def home():
    """Redirects to dashboard if logged in, otherwise to login."""
    return redirect(url_for('dashboard') if current_user() else url_for('login'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    """Handles new user registration."""
    if request.method == 'POST':
        name = request.form.get('name', '').strip()[:100]
        email = request.form.get('email', '').strip().lower()[:200]
        password = request.form.get('password', '')
        
        # Validation
        if not name or '@' not in email or len(password) < 8:
            flash('Enter a name, valid email and password of at least 8 characters.', 'error')
        else:
            try:
                cur = db().execute(
                    'INSERT INTO users(name,email,password_hash,role,created_at) VALUES(?,?,?,?,?)',
                    (name, email, generate_password_hash(password), 'customer', now())
                )
                db().commit()
                session.clear() # Prevent session fixation
                session['user_id'] = cur.lastrowid
                return redirect(url_for('dashboard'))
            except sqlite3.IntegrityError:
                flash('This email is already registered.', 'error')
                
    return render_template('auth.html', mode='register')

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Handles user authentication."""
    if request.method == 'POST':
        email = request.form.get('email', '').strip().lower()
        user = db().execute('SELECT * FROM users WHERE email=?', (email,)).fetchone()
        
        # Security: check_password_hash safely compares the raw password to the stored hash
        if user and check_password_hash(user['password_hash'], request.form.get('password', '')):
            session.clear() # Prevent session fixation
            session['user_id'] = user['id']
            return redirect(url_for('dashboard'))
            
        # Security: Identical error message for unknown email vs wrong password prevents user enumeration
        flash('Incorrect email or password.', 'error')
        
    return render_template('auth.html', mode='login')

@app.post('/logout')
@login_required
def logout():
    """Clears the session and logs the user out."""
    session.clear()
    return redirect(url_for('login'))


# =====================================================================
# 5. TICKET ROUTES
# =====================================================================
@app.route('/dashboard')
@login_required
def dashboard():
    """Displays the ticket list and status counts based on user role."""
    u = current_user()
    
    # Data Isolation: Customers only see their own tickets. Staff see all.
    where = 'WHERE t.customer_id=?' if u['role'] == 'customer' else ''
    args = (u['id'],) if where else ()
    
    tickets = db().execute(f'''
        SELECT t.*, c.name customer_name, a.name assigned_name 
        FROM tickets t
        JOIN users c ON c.id=t.customer_id 
        LEFT JOIN users a ON a.id=t.assigned_to 
        {where}
        ORDER BY t.updated_at DESC, t.id DESC
    ''', args).fetchall()
    
    # Calculate dashboard stats
    counts = {s: sum(t['status'] == s for t in tickets) for s in STATUSES}
    
    return render_template('dashboard.html', tickets=tickets, counts=counts, statuses=STATUSES)

@app.route('/tickets/new', methods=['GET', 'POST'])
@login_required
def new_ticket():
    """Handles the creation of a new support ticket."""
    if request.method == 'POST':
        title = request.form.get('title', '').strip()[:150]
        description = request.form.get('description', '').strip()[:5000]
        priority = request.form.get('priority', 'Medium')
        category = request.form.get('category', 'General')
        
        # Validate against allow-lists
        if not title or not description or priority not in PRIORITIES or category not in CATEGORIES:
            flash('Please complete all fields with valid selections.', 'error')
        else:
            u = current_user()
            cur = db().execute('''
                INSERT INTO tickets(customer_id,title,description,category,priority,status,created_at,updated_at)
                VALUES(?,?,?,?,?,?,?,?)
            ''', (u['id'], title, description, category, priority, 'Open', now(), now()))
            db().commit()
            flash('Ticket created successfully.', 'success')
            return redirect(url_for('ticket_detail', ticket_id=cur.lastrowid))
            
    return render_template('new_ticket.html', priorities=PRIORITIES, categories=CATEGORIES)

def get_ticket(ticket_id):
    """Helper function to fetch a ticket and enforce access control."""
    ticket = db().execute('''
        SELECT t.*, c.name customer_name, c.email customer_email, a.name assigned_name
        FROM tickets t 
        JOIN users c ON c.id=t.customer_id 
        LEFT JOIN users a ON a.id=t.assigned_to 
        WHERE t.id=?
    ''', (ticket_id,)).fetchone()
    
    if not ticket:
        abort(404)
        
    # CRITICAL SECURITY CONTROL: Prevent cross-customer access
    u = current_user()
    if u['role'] == 'customer' and ticket['customer_id'] != u['id']:
        abort(403) # Forbidden
        
    return ticket

@app.route('/tickets/<int:ticket_id>')
@login_required
def ticket_detail(ticket_id):
    """Displays a specific ticket and its conversation."""
    ticket = get_ticket(ticket_id) # Enforces access control
    
    comments = db().execute('''
        SELECT m.*, u.name author_name, u.role author_role 
        FROM comments m 
        JOIN users u ON u.id=m.user_id 
        WHERE m.ticket_id=? 
        ORDER BY m.created_at, m.id
    ''', (ticket_id,)).fetchall()
    
    staff = db().execute("SELECT id, name, role FROM users WHERE role IN ('agent','admin') ORDER BY name").fetchall()
    
    return render_template('ticket.html', ticket=ticket, comments=comments, staff=staff, statuses=STATUSES, priorities=PRIORITIES)

@app.post('/tickets/<int:ticket_id>/comment')
@login_required
def add_comment(ticket_id):
    """Adds a comment to a ticket."""
    get_ticket(ticket_id) # Enforces access control before allowing comment
    
    body = request.form.get('body', '').strip()[:3000]
    
    if not body:
        flash('Comment cannot be empty.', 'error')
    else:
        db().execute('INSERT INTO comments(ticket_id,user_id,body,created_at) VALUES(?,?,?,?)', 
                     (ticket_id, current_user()['id'], body, now()))
        # Touch the ticket's updated_at timestamp so it rises to the top of the dashboard
        db().execute('UPDATE tickets SET updated_at=? WHERE id=?', (now(), ticket_id))
        db().commit()
        flash('Comment posted.', 'success')
        
    return redirect(url_for('ticket_detail', ticket_id=ticket_id))

@app.post('/tickets/<int:ticket_id>/update')
@login_required
def update_ticket(ticket_id):
    """Allows Agents/Admins to update status, priority, and assignee."""
    get_ticket(ticket_id) # Enforces access control
    
    # Role restriction
    if current_user()['role'] not in ('agent', 'admin'):
        abort(403)
        
    status = request.form.get('status', '')
    priority = request.form.get('priority', '')
    assigned = request.form.get('assigned_to', '')
    
    if status not in STATUSES or priority not in PRIORITIES:
        abort(400)
        
    assigned_id = None
    if assigned:
        if not assigned.isdigit():
            abort(400)
        # Verify the assignee actually has a staff role
        staff = db().execute("SELECT id FROM users WHERE id=? AND role IN ('agent','admin')", (int(assigned),)).fetchone()
        if not staff:
            abort(400)
        assigned_id = staff['id']
        
    db().execute('UPDATE tickets SET status=?, priority=?, assigned_to=?, updated_at=? WHERE id=?', 
                 (status, priority, assigned_id, now(), ticket_id))
    db().commit()
    flash('Ticket updated.', 'success')
    
    return redirect(url_for('ticket_detail', ticket_id=ticket_id))


# =====================================================================
# 6. CLI COMMANDS (Custom flask commands)
# =====================================================================
@app.cli.command('init-db')
def init_db_command():
    """Creates the database tables."""
    init_db()
    print('Database initialized.')

@app.cli.command('seed-demo')
def seed_demo():
    """Populates the database with demo users and a sample ticket."""
    init_db()
    
    demo_users = [
        ('Admin User', 'admin@smartdesk.local', 'admin'),
        ('Support Agent', 'agent@smartdesk.local', 'agent'),
        ('Demo Customer', 'customer@smartdesk.local', 'customer')
    ]
    
    # Create users (idempotent via INSERT OR IGNORE)
    for name, email, role in demo_users:
        db().execute('INSERT OR IGNORE INTO users(name,email,password_hash,role,created_at) VALUES(?,?,?,?,?)', 
                     (name, email, generate_password_hash('DemoPass123!'), role, now()))
    db().commit()
    
    # Create a sample ticket if the database is empty
    customer = db().execute("SELECT id FROM users WHERE email='customer@smartdesk.local'").fetchone()['id']
    if not db().execute('SELECT id FROM tickets LIMIT 1').fetchone():
        db().execute('INSERT INTO tickets(customer_id,title,description,category,priority,status,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)', 
                     (customer, 'Unable to access customer portal', 'Login page returns an error after submitting my credentials.', 'Technical', 'High', 'Open', now(), now()))
        db().commit()
        
    print('Demo users ready. Password for all three: DemoPass123! (change before any deployment)')


# =====================================================================
# 7. APPLICATION ENTRY POINT
# =====================================================================
if __name__ == '__main__':
    # Ensure database is initialized before running
    init_db()
    app.run(debug=os.environ.get('FLASK_DEBUG') == '1', host='127.0.0.1', port=int(os.environ.get('PORT', 5000)))