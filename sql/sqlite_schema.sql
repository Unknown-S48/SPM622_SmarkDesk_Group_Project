CREATE TABLE IF NOT EXISTS users (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 name TEXT NOT NULL,
 email TEXT NOT NULL UNIQUE,
 password_hash TEXT NOT NULL,
 role TEXT NOT NULL DEFAULT 'customer' CHECK(role IN ('customer','agent','admin')),
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tickets (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 customer_id INTEGER NOT NULL REFERENCES users(id),
 assigned_to INTEGER REFERENCES users(id),
 title TEXT NOT NULL,
 description TEXT NOT NULL,
 category TEXT NOT NULL CHECK(category IN ('Account','Billing','Technical','Product','General')),
 priority TEXT NOT NULL CHECK(priority IN ('Low','Medium','High','Critical')),
 status TEXT NOT NULL CHECK(status IN ('Open','In Progress','Pending','Resolved','Closed')),
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS comments (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
 user_id INTEGER NOT NULL REFERENCES users(id),
 body TEXT NOT NULL,
 created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_tickets_customer ON tickets(customer_id);
CREATE INDEX IF NOT EXISTS ix_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS ix_comments_ticket ON comments(ticket_id);
