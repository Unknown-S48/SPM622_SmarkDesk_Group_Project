import os, sqlite3, secrets
from datetime import datetime, timezone
from functools import wraps
from pathlib import Path
from flask import Flask, render_template, request, redirect, url_for, flash, session, abort, g
from werkzeug.security import generate_password_hash, check_password_hash

BASE = Path(__file__).resolve().parent
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'development-only-change-this-key')
app.config['DATABASE'] = os.environ.get('DATABASE_PATH', str(BASE / 'support.db'))
STATUSES = ('Open', 'In Progress', 'Pending', 'Resolved', 'Closed')
PRIORITIES = ('Low', 'Medium', 'High', 'Critical')
CATEGORIES = ('Account', 'Billing', 'Technical', 'Product', 'General')

def db():
    if 'db' not in g:
        g.db = sqlite3.connect(app.config['DATABASE'])
        g.db.row_factory = sqlite3.Row
        g.db.execute('PRAGMA foreign_keys=ON')
    return g.db

@app.teardown_appcontext
def close_db(exc):
    conn = g.pop('db', None)
    if conn: conn.close()

def init_db():
    with app.app_context():
        db().executescript((BASE/'sql'/'sqlite_schema.sql').read_text())
        db().commit()

def now(): return datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')

def current_user():
    if 'user_id' not in session: return None
    return db().execute('SELECT id,name,email,role FROM users WHERE id=?',(session['user_id'],)).fetchone()

def login_required(fn):
    @wraps(fn)
    def inner(*a, **kw):
        if not current_user(): return redirect(url_for('login'))
        return fn(*a, **kw)
    return inner

def csrf_token():
    if '_csrf' not in session: session['_csrf'] = secrets.token_hex(24)
    return session['_csrf']
app.jinja_env.globals['csrf_token'] = csrf_token
app.jinja_env.globals['current_user'] = current_user

@app.before_request
def protect_forms():
    if request.method == 'POST':
        if not secrets.compare_digest(str(session.get('_csrf','')),str(request.form.get('_csrf',''))):
            abort(400, 'Invalid CSRF token. Refresh the page and try again.')

@app.route('/')
def home(): return redirect(url_for('dashboard') if current_user() else url_for('login'))

@app.route('/register', methods=['GET','POST'])
def register():
    if request.method=='POST':
        name=request.form.get('name','').strip()[:100]
        email=request.form.get('email','').strip().lower()[:200]
        password=request.form.get('password','')
        if not name or '@' not in email or len(password)<8:
            flash('Enter a name, valid email and password of at least 8 characters.','error')
        else:
            try:
                cur=db().execute('INSERT INTO users(name,email,password_hash,role,created_at) VALUES(?,?,?,?,?)',(name,email,generate_password_hash(password),'customer',now()))
                db().commit(); session.clear(); session['user_id']=cur.lastrowid
                return redirect(url_for('dashboard'))
            except sqlite3.IntegrityError: flash('This email is already registered.','error')
    return render_template('auth.html',mode='register')

@app.route('/login',methods=['GET','POST'])
def login():
    if request.method=='POST':
        email=request.form.get('email','').strip().lower()
        u=db().execute('SELECT * FROM users WHERE email=?',(email,)).fetchone()
        if u and check_password_hash(u['password_hash'],request.form.get('password','')):
            session.clear(); session['user_id']=u['id']; return redirect(url_for('dashboard'))
        flash('Incorrect email or password.','error')
    return render_template('auth.html',mode='login')

@app.post('/logout')
@login_required
def logout(): session.clear(); return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    u=current_user()
    where='WHERE t.customer_id=?' if u['role']=='customer' else ''
    args=(u['id'],) if where else ()
    tickets=db().execute(f'''SELECT t.*, c.name customer_name, a.name assigned_name FROM tickets t
        JOIN users c ON c.id=t.customer_id LEFT JOIN users a ON a.id=t.assigned_to {where}
        ORDER BY t.updated_at DESC, t.id DESC''',args).fetchall()
    counts={s:sum(t['status']==s for t in tickets) for s in STATUSES}
    return render_template('dashboard.html',tickets=tickets,counts=counts,statuses=STATUSES)

@app.route('/tickets/new',methods=['GET','POST'])
@login_required
def new_ticket():
    if request.method=='POST':
        title=request.form.get('title','').strip()[:150]
        description=request.form.get('description','').strip()[:5000]
        priority=request.form.get('priority','Medium')
        category=request.form.get('category','General')
        if not title or not description or priority not in PRIORITIES or category not in CATEGORIES:
            flash('Please complete all fields with valid selections.','error')
        else:
            u=current_user()
            cur=db().execute('''INSERT INTO tickets(customer_id,title,description,category,priority,status,created_at,updated_at)
                VALUES(?,?,?,?,?,?,?,?)''',(u['id'],title,description,category,priority,'Open',now(),now()))
            db().commit(); flash('Ticket created successfully.','success')
            return redirect(url_for('ticket_detail',ticket_id=cur.lastrowid))
    return render_template('new_ticket.html',priorities=PRIORITIES,categories=CATEGORIES)

def get_ticket(ticket_id):
    ticket=db().execute('''SELECT t.*,c.name customer_name,c.email customer_email,a.name assigned_name
        FROM tickets t JOIN users c ON c.id=t.customer_id LEFT JOIN users a ON a.id=t.assigned_to WHERE t.id=?''',(ticket_id,)).fetchone()
    if not ticket: abort(404)
    u=current_user()
    if u['role']=='customer' and ticket['customer_id']!=u['id']: abort(403)
    return ticket

@app.route('/tickets/<int:ticket_id>')
@login_required
def ticket_detail(ticket_id):
    ticket=get_ticket(ticket_id)
    comments=db().execute('''SELECT m.*,u.name author_name,u.role author_role FROM comments m JOIN users u ON u.id=m.user_id WHERE m.ticket_id=? ORDER BY m.created_at,m.id''',(ticket_id,)).fetchall()
    staff=db().execute("SELECT id,name,role FROM users WHERE role IN ('agent','admin') ORDER BY name").fetchall()
    return render_template('ticket.html',ticket=ticket,comments=comments,staff=staff,statuses=STATUSES,priorities=PRIORITIES)

@app.post('/tickets/<int:ticket_id>/comment')
@login_required
def add_comment(ticket_id):
    get_ticket(ticket_id)
    body=request.form.get('body','').strip()[:3000]
    if not body: flash('Comment cannot be empty.','error')
    else:
        db().execute('INSERT INTO comments(ticket_id,user_id,body,created_at) VALUES(?,?,?,?)',(ticket_id,current_user()['id'],body,now()))
        db().execute('UPDATE tickets SET updated_at=? WHERE id=?',(now(),ticket_id))
        db().commit(); flash('Comment posted.','success')
    return redirect(url_for('ticket_detail',ticket_id=ticket_id))

@app.post('/tickets/<int:ticket_id>/update')
@login_required
def update_ticket(ticket_id):
    get_ticket(ticket_id)
    if current_user()['role'] not in ('agent','admin'): abort(403)
    status=request.form.get('status','')
    priority=request.form.get('priority','')
    assigned=request.form.get('assigned_to','')
    if status not in STATUSES or priority not in PRIORITIES: abort(400)
    assigned_id=None
    if assigned:
        if not assigned.isdigit(): abort(400)
        staff=db().execute("SELECT id FROM users WHERE id=? AND role IN ('agent','admin')",(int(assigned),)).fetchone()
        if not staff: abort(400)
        assigned_id=staff['id']
    db().execute('UPDATE tickets SET status=?,priority=?,assigned_to=?,updated_at=? WHERE id=?',(status,priority,assigned_id,now(),ticket_id))
    db().commit(); flash('Ticket updated.','success')
    return redirect(url_for('ticket_detail',ticket_id=ticket_id))

@app.cli.command('init-db')
def init_db_command(): init_db(); print('Database initialized.')

@app.cli.command('seed-demo')
def seed_demo():
    init_db()
    demo=[('Admin User','admin@smartdesk.local','admin'),('Support Agent','agent@smartdesk.local','agent'),('Demo Customer','customer@smartdesk.local','customer')]
    for name,email,role in demo:
        db().execute('INSERT OR IGNORE INTO users(name,email,password_hash,role,created_at) VALUES(?,?,?,?,?)',(name,email,generate_password_hash('DemoPass123!'),role,now()))
    db().commit()
    customer=db().execute("SELECT id FROM users WHERE email='customer@smartdesk.local'").fetchone()['id']
    if not db().execute('SELECT id FROM tickets LIMIT 1').fetchone():
        db().execute('INSERT INTO tickets(customer_id,title,description,category,priority,status,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)',(customer,'Unable to access customer portal','Login page returns an error after submitting my credentials.','Technical','High','Open',now(),now()))
        db().commit()
    print('Demo users ready. Password for all three: DemoPass123! (change before any deployment)')

if __name__=='__main__':
    init_db()
    app.run(debug=os.environ.get('FLASK_DEBUG')=='1',host='127.0.0.1',port=int(os.environ.get('PORT',5000)))
