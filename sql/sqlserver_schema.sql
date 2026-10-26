/* =====================================================================
   SMARTDESK - MICROSOFT SQL SERVER 2022+ SCHEMA
   Coursework artefact for MDB622 (Parallel to the SQLite runtime DB)
   Execute in SSMS on a test instance.
   ===================================================================== */

-- 1. DATABASE CREATION
-- Checks if the database exists before creating it to prevent errors on re-run
IF DB_ID(N'CustomerSupportDB') IS NULL 
    CREATE DATABASE CustomerSupportDB;
GO

USE CustomerSupportDB;
GO

/* =====================================================================
   2. TABLE: USERS
   Stores all accounts (Customers, Agents, Admins) with role enforcement.
   ===================================================================== */
IF OBJECT_ID('dbo.Users','U') IS NULL
CREATE TABLE dbo.Users (
    UserID       INT IDENTITY(1,1) PRIMARY KEY,      -- Auto-incrementing primary key
    FullName     NVARCHAR(100) NOT NULL,             -- User's display name
    Email        NVARCHAR(200) NOT NULL UNIQUE,      -- Login identifier (must be unique)
    PasswordHash NVARCHAR(255) NOT NULL,             -- One-way hash (never plain text)
    UserRole     NVARCHAR(20) NOT NULL DEFAULT 'customer', 
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    
    -- Security: Restricts roles to only these three valid values
    CONSTRAINT CK_Users_Role CHECK(UserRole IN ('customer','agent','admin'))
);
GO

/* =====================================================================
   3. TABLE: TICKETS
   Stores the core support requests, linking to Users for customer/assignee.
   ===================================================================== */
IF OBJECT_ID('dbo.Tickets','U') IS NULL
CREATE TABLE dbo.Tickets (
    TicketID     INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID   INT NOT NULL REFERENCES dbo.Users(UserID), -- Ticket must have a creator
    AssignedTo   INT NULL REFERENCES dbo.Users(UserID),     -- Nullable (tickets can be unassigned)
    Title        NVARCHAR(150) NOT NULL,
    Description  NVARCHAR(MAX) NOT NULL,
    Category     NVARCHAR(30) NOT NULL,
    Priority     NVARCHAR(20) NOT NULL DEFAULT 'Medium',
    TicketStatus NVARCHAR(30) NOT NULL DEFAULT 'Open',
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    
    -- Data Integrity: Enforces specific allowed values for categories
    CONSTRAINT CK_Tickets_Category CHECK(Category IN ('Account','Billing','Technical','Product','General')),
    
    -- Data Integrity: Enforces specific allowed values for priority levels
    CONSTRAINT CK_Tickets_Priority CHECK(Priority IN ('Low','Medium','High','Critical')),
    
    -- Data Integrity: Enforces the workflow states
    CONSTRAINT CK_Tickets_Status CHECK(TicketStatus IN ('Open','In Progress','Pending','Resolved','Closed'))
);
GO

/* =====================================================================
   4. TABLE: TICKET COMMENTS
   Stores the chronological conversation history for each ticket.
   ===================================================================== */
IF OBJECT_ID('dbo.TicketComments','U') IS NULL
CREATE TABLE dbo.TicketComments (
    CommentID    INT IDENTITY(1,1) PRIMARY KEY,
    TicketID     INT NOT NULL REFERENCES dbo.Tickets(TicketID) ON DELETE CASCADE, -- Deletes comments if ticket is deleted
    UserID       INT NOT NULL REFERENCES dbo.Users(UserID),                       -- Who wrote the comment
    CommentText  NVARCHAR(3000) NOT NULL,
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/* =====================================================================
   5. INDEXES
   Improves query performance for common dashboard lookups.
   ===================================================================== */
-- Index for quickly finding all tickets belonging to a specific customer
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Tickets_Customer' AND object_id=OBJECT_ID('dbo.Tickets'))
    CREATE INDEX IX_Tickets_Customer ON dbo.Tickets(CustomerID);

-- Index for quickly filtering the dashboard by ticket status
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Tickets_Status' AND object_id=OBJECT_ID('dbo.Tickets'))
    CREATE INDEX IX_Tickets_Status ON dbo.Tickets(TicketStatus);
GO

/* =====================================================================
   6. REPORTING QUERIES
   Used for dashboard stats and workload monitoring.
   ===================================================================== */

-- Dashboard Stat 1: Count of tickets grouped by their current status
SELECT TicketStatus, COUNT(*) AS TotalTickets 
FROM dbo.Tickets 
GROUP BY TicketStatus;

-- Dashboard Stat 2: Count of tickets grouped by priority (to see urgent workload)
SELECT Priority, COUNT(*) AS TotalTickets 
FROM dbo.Tickets 
GROUP BY Priority;

-- Recent Activity: Get the 10 most recently created tickets
SELECT TOP (10) TicketID, Title, TicketStatus, Priority, CreatedAt 
FROM dbo.Tickets 
ORDER BY CreatedAt DESC;
GO