/* =====================================================================
   SMARTDESK - SQLITE RUNTIME DATABASE SCHEMA
   This file creates the database structure used by the Flask application.
   It is executed by the command: flask init-db
   ===================================================================== */

-- NOTE: SQLite ignores foreign key constraints by default. 
-- The Flask application must enable them on startup using: PRAGMA foreign_keys = ON;

/* =====================================================================
   1. TABLE: USERS
   Stores all accounts (customers, agents, and administrators).
   ===================================================================== */
CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT, -- Unique identifier
    name          TEXT NOT NULL,                     -- Full name for display
    email         TEXT NOT NULL UNIQUE,              -- Login identifier (must be unique)
    password_hash TEXT NOT NULL,                     -- Secure one-way hash (Werkzeug)
    role          TEXT NOT NULL DEFAULT 'customer',  -- Role-based access control
    created_at    TEXT NOT NULL,                     -- UTC timestamp
    
    -- Data Integrity: Restrict roles to only these three values
    CHECK(role IN ('customer', 'agent', 'admin'))
);

/* =====================================================================
   2. TABLE: TICKETS
   Stores the core support requests. Links to the Users table twice:
   once for the customer who created it, and once for the assigned agent.
   ===================================================================== */
CREATE TABLE IF NOT EXISTS tickets (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL REFERENCES users(id), -- The customer who logged the ticket
    assigned_to INTEGER REFERENCES users(id),         -- The staff member assigned (Nullable = unassigned)
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    category    TEXT NOT NULL,
    priority    TEXT NOT NULL,
    status      TEXT NOT NULL,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,

    -- Data Integrity: Enforce specific categories (using allow-list CHECK)
    CHECK(category IN ('Account', 'Billing', 'Technical', 'Product', 'General')),
    
    -- Data Integrity: Enforce priority levels
    CHECK(priority IN ('Low', 'Medium', 'High', 'Critical')),
    
    -- Data Integrity: Enforce the ticket lifecycle states
    CHECK(status IN ('Open', 'In Progress', 'Pending', 'Resolved', 'Closed'))
);

/* =====================================================================
   3. TABLE: COMMENTS
   Stores the chronological conversation attached to each ticket.
   ===================================================================== */
CREATE TABLE IF NOT EXISTS comments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_id  INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE, -- Delete comments if ticket is deleted
    user_id    INTEGER NOT NULL REFERENCES users(id),                     -- The author of the comment
    body       TEXT NOT NULL,                                             -- The actual comment text
    created_at TEXT NOT NULL                                              -- Used for ordering the conversation
);

/* =====================================================================
   4. INDEXES
   Improves query performance for the dashboard and ticket lists.
   ===================================================================== */

-- Speeds up the dashboard query that finds all tickets belonging to a specific customer
CREATE INDEX IF NOT EXISTS ix_tickets_customer ON tickets(customer_id);

-- Speeds up filtering by status (e.g., showing only 'Open' tickets)
CREATE INDEX IF NOT EXISTS ix_tickets_status ON tickets(status);

-- Speeds up loading the conversation history on the ticket detail page
CREATE INDEX IF NOT EXISTS ix_comments_ticket ON comments(ticket_id);