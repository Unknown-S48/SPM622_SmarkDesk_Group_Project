/* =====================================================================
   SmartDesk — Microsoft SQL Server 2022 schema
   Group Fish — Freek Schaefer-Gerber, Wian Sandenbergh
   Module: MDB622 / SPM622      Date: 29 October 2026

   IMPORTANT: The running Flask application uses SQLite
   (see sql/sqlite_schema.sql). This script is the MDB622
   database-design deliverable and is NOT used at runtime.

   Meets MDB622 minimums: 8 tables, 13 INSERTs, 5 UPDATEs,
   5 DELETEs, 6 JOINs, 2 views, 2 stored procedures with transactions.
   ===================================================================== */

IF DB_ID(N'SmartDeskDB') IS NULL CREATE DATABASE SmartDeskDB;
GO
USE SmartDeskDB;
GO

/* ---------- Clean rebuild (safe to re-run) ---------- */
IF OBJECT_ID('dbo.sp_AssignTicket','P') IS NOT NULL DROP PROCEDURE dbo.sp_AssignTicket;
IF OBJECT_ID('dbo.sp_CreateTicket','P') IS NOT NULL DROP PROCEDURE dbo.sp_CreateTicket;
IF OBJECT_ID('dbo.vw_TicketSummary','V') IS NOT NULL DROP VIEW dbo.vw_TicketSummary;
IF OBJECT_ID('dbo.vw_OpenTickets','V')  IS NOT NULL DROP VIEW dbo.vw_OpenTickets;
IF OBJECT_ID('dbo.TicketHistory','U')   IS NOT NULL DROP TABLE dbo.TicketHistory;
IF OBJECT_ID('dbo.TicketComments','U')  IS NOT NULL DROP TABLE dbo.TicketComments;
IF OBJECT_ID('dbo.Tickets','U')         IS NOT NULL DROP TABLE dbo.Tickets;
IF OBJECT_ID('dbo.Statuses','U')        IS NOT NULL DROP TABLE dbo.Statuses;
IF OBJECT_ID('dbo.Priorities','U')      IS NOT NULL DROP TABLE dbo.Priorities;
IF OBJECT_ID('dbo.Categories','U')      IS NOT NULL DROP TABLE dbo.Categories;
IF OBJECT_ID('dbo.Users','U')           IS NOT NULL DROP TABLE dbo.Users;
IF OBJECT_ID('dbo.Roles','U')           IS NOT NULL DROP TABLE dbo.Roles;
GO

/* =====================================================================
   1. LOOKUP TABLES  (removes transitive dependencies — 3NF)
   ===================================================================== */
CREATE TABLE dbo.Roles (
    RoleId   INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(20) NOT NULL UNIQUE
);
CREATE TABLE dbo.Categories (
    CategoryId   INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(40) NOT NULL UNIQUE
);
CREATE TABLE dbo.Priorities (
    PriorityId   INT IDENTITY(1,1) PRIMARY KEY,
    PriorityName NVARCHAR(20) NOT NULL UNIQUE,
    SortOrder    TINYINT NOT NULL
);
CREATE TABLE dbo.Statuses (
    StatusId   INT IDENTITY(1,1) PRIMARY KEY,
    StatusName NVARCHAR(20) NOT NULL UNIQUE
);
GO

/* =====================================================================
   2. CORE TABLES
   ===================================================================== */
CREATE TABLE dbo.Users (
    UserId       INT IDENTITY(1,1) PRIMARY KEY,
    FullName     NVARCHAR(100) NOT NULL,
    Email        NVARCHAR(200) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    RoleId       INT NOT NULL REFERENCES dbo.Roles(RoleId),
    IsActive     BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
    CreatedAt    DATETIME2 NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Tickets (
    TicketId    INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId  INT NOT NULL REFERENCES dbo.Users(UserId),
    AssignedTo  INT NULL     REFERENCES dbo.Users(UserId),
    Title       NVARCHAR(150) NOT NULL,
    Description NVARCHAR(MAX) NOT NULL,
    CategoryId  INT NOT NULL REFERENCES dbo.Categories(CategoryId),
    PriorityId  INT NOT NULL REFERENCES dbo.Priorities(PriorityId),
    StatusId    INT NOT NULL REFERENCES dbo.Statuses(StatusId),
    CreatedAt   DATETIME2 NOT NULL CONSTRAINT DF_Tickets_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt   DATETIME2 NOT NULL CONSTRAINT DF_Tickets_UpdatedAt DEFAULT SYSUTCDATETIME(),
    ResolvedAt  DATETIME2 NULL,
    CONSTRAINT CK_Tickets_Resolved CHECK (ResolvedAt IS NULL OR ResolvedAt >= CreatedAt)
);

CREATE TABLE dbo.TicketComments (
    CommentId   INT IDENTITY(1,1) PRIMARY KEY,
    TicketId    INT NOT NULL REFERENCES dbo.Tickets(TicketId) ON DELETE CASCADE,
    UserId      INT NOT NULL REFERENCES dbo.Users(UserId),
    CommentText NVARCHAR(3000) NOT NULL,
    CreatedAt   DATETIME2 NOT NULL CONSTRAINT DF_Comments_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.TicketHistory (
    HistoryId INT IDENTITY(1,1) PRIMARY KEY,
    TicketId  INT NOT NULL REFERENCES dbo.Tickets(TicketId) ON DELETE CASCADE,
    UserId    INT NOT NULL REFERENCES dbo.Users(UserId),
    FieldName NVARCHAR(20) NOT NULL
              CONSTRAINT CK_History_Field
              CHECK (FieldName IN ('created','status','priority','assigned_to')),
    OldValue  NVARCHAR(100) NULL,
    NewValue  NVARCHAR(100) NOT NULL,
    ChangedAt DATETIME2 NOT NULL CONSTRAINT DF_History_ChangedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_Tickets_Customer ON dbo.Tickets(CustomerId);
CREATE INDEX IX_Tickets_Status   ON dbo.Tickets(StatusId);
CREATE INDEX IX_Tickets_Assigned ON dbo.Tickets(AssignedTo);
CREATE INDEX IX_Comments_Ticket  ON dbo.TicketComments(TicketId);
CREATE INDEX IX_History_Ticket   ON dbo.TicketHistory(TicketId);
GO

/* =====================================================================
   3. SEED DATA — 13 INSERT statements (minimum 10)
   ===================================================================== */
-- INSERT 1
INSERT INTO dbo.Roles (RoleName) VALUES ('customer'),('agent'),('admin');

-- INSERT 2
INSERT INTO dbo.Categories (CategoryName)
VALUES ('Account'),('Billing'),('Technical'),('Product'),('General');

-- INSERT 3
INSERT INTO dbo.Priorities (PriorityName, SortOrder)
VALUES ('Low',1),('Medium',2),('High',3),('Critical',4);

-- INSERT 4
INSERT INTO dbo.Statuses (StatusName)
VALUES ('Open'),('In Progress'),('Pending'),('Resolved'),('Closed');

-- INSERT 5 — placeholder hashes only; never store real credentials in a script
INSERT INTO dbo.Users (FullName, Email, PasswordHash, RoleId) VALUES
 ('Admin User',     'admin@smartdesk.local',    'PLACEHOLDER_HASH_ADMIN',    3),
 ('Support Agent',  'agent@smartdesk.local',    'PLACEHOLDER_HASH_AGENT',    2),
 ('Demo Customer',  'customer@smartdesk.local', 'PLACEHOLDER_HASH_CUSTOMER', 1),
 ('Thandi Nkosi',   'thandi@example.com',       'PLACEHOLDER_HASH_4',        1),
 ('Riaan Botha',    'riaan@example.com',        'PLACEHOLDER_HASH_5',        1),
 ('Lerato Mokoena', 'lerato@example.com',       'PLACEHOLDER_HASH_6',        1),
 ('Second Agent',   'agent2@smartdesk.local',   'PLACEHOLDER_HASH_7',        2);

-- INSERT 6
INSERT INTO dbo.Tickets
 (CustomerId, AssignedTo, Title, Description, CategoryId, PriorityId, StatusId, ResolvedAt) VALUES
 (3, 2,    'Unable to access customer portal','Login page errors after submitting credentials.',3,3,1,NULL),
 (4, 2,    'Invoice amount incorrect',        'February invoice charged twice.',                2,3,2,NULL),
 (5, NULL, 'Feature request: dark mode',      'Please add a dark theme.',                       4,1,1,NULL),
 (6, 7,    'Password reset email not arriving','Three reset requests, no email.',               1,4,2,NULL),
 (4, NULL, 'Report export fails',             'CSV export errors above 90 days.',               3,2,3,NULL),
 (3, 2,    'Duplicate charge on card',        'Card charged twice for renewal.',                2,4,4,SYSUTCDATETIME());

-- INSERT 7
INSERT INTO dbo.TicketComments (TicketId, UserId, CommentText) VALUES
 (1, 3, 'This started after weekend maintenance.'),
 (1, 2, 'Investigating the auth service now.'),
 (2, 4, 'Invoice reference INV-2026-0231.'),
 (2, 2, 'Confirmed duplicate billing. Refund raised.'),
 (4, 6, 'Nothing in inbox or spam folder.');

-- INSERT 8 — initial creation records
INSERT INTO dbo.TicketHistory (TicketId, UserId, FieldName, OldValue, NewValue) VALUES
 (1,3,'created',NULL,'Open'),(2,4,'created',NULL,'Open'),
 (3,5,'created',NULL,'Open'),(4,6,'created',NULL,'Open'),
 (5,4,'created',NULL,'Open'),(6,3,'created',NULL,'Open');

-- INSERT 9 — assignment records
INSERT INTO dbo.TicketHistory (TicketId, UserId, FieldName, OldValue, NewValue) VALUES
 (1,1,'assigned_to',NULL,'2'),(2,1,'assigned_to',NULL,'2'),
 (4,1,'assigned_to',NULL,'7');

-- INSERT 10 — status transitions
INSERT INTO dbo.TicketHistory (TicketId, UserId, FieldName, OldValue, NewValue) VALUES
 (2,2,'status','1','2'),(4,7,'status','1','2'),
 (5,4,'status','1','3'),(6,2,'status','2','4');

-- INSERT 11 — disposable users for the DELETE section
INSERT INTO dbo.Users (FullName, Email, PasswordHash, RoleId) VALUES
 ('Disposable One','disposable1@example.com','PLACEHOLDER_HASH_X1',1),
 ('Disposable Two','disposable2@example.com','PLACEHOLDER_HASH_X2',1);

-- INSERT 12 — disposable tickets
INSERT INTO dbo.Tickets (CustomerId, Title, Description, CategoryId, PriorityId, StatusId) VALUES
 (3,'Disposable ticket A','For DELETE demonstration.',5,1,1),
 (3,'Disposable ticket B','For DELETE demonstration.',5,1,1);

-- INSERT 13 — disposable comments
INSERT INTO dbo.TicketComments (TicketId, UserId, CommentText) VALUES
 ((SELECT MIN(TicketId) FROM dbo.Tickets WHERE Title='Disposable ticket A'),3,'Disposable comment A.'),
 ((SELECT MIN(TicketId) FROM dbo.Tickets WHERE Title='Disposable ticket B'),3,'Disposable comment B.');
GO

/* =====================================================================
   4. UPDATE STATEMENTS — 5 (minimum 5)
   ===================================================================== */
-- UPDATE 1
UPDATE dbo.Tickets SET StatusId=2, UpdatedAt=SYSUTCDATETIME() WHERE TicketId=1;
-- UPDATE 2
UPDATE dbo.Tickets SET PriorityId=2, UpdatedAt=SYSUTCDATETIME() WHERE TicketId=3;
-- UPDATE 3
UPDATE dbo.Tickets SET AssignedTo=7, UpdatedAt=SYSUTCDATETIME() WHERE TicketId=5;
-- UPDATE 4
UPDATE dbo.Users  SET IsActive=0 WHERE Email='riaan@example.com';
-- UPDATE 5
UPDATE dbo.Tickets
SET ResolvedAt=SYSUTCDATETIME(), UpdatedAt=SYSUTCDATETIME()
WHERE StatusId=4 AND ResolvedAt IS NULL;
GO

/* =====================================================================
   5. DELETE STATEMENTS — 5 (minimum 5)
   All target disposable rows so referential integrity is preserved.
   ===================================================================== */
-- DELETE 1
DELETE FROM dbo.TicketComments WHERE CommentText='Disposable comment A.';
-- DELETE 2
DELETE FROM dbo.TicketComments WHERE CommentText='Disposable comment B.';
-- DELETE 3
DELETE FROM dbo.Tickets WHERE Title='Disposable ticket A';
-- DELETE 4
DELETE FROM dbo.Tickets WHERE Title='Disposable ticket B';
-- DELETE 5
DELETE FROM dbo.Users WHERE Email IN ('disposable1@example.com','disposable2@example.com');
GO

/* =====================================================================
   6. JOIN QUERIES — 6 (minimum 5)
   ===================================================================== */
-- JOIN 1: tickets with customer, assignee, category, priority, status
SELECT t.TicketId, t.Title,
       cu.FullName AS Customer,
       ISNULL(ag.FullName,'Unassigned') AS Assignee,
       cat.CategoryName, pri.PriorityName, st.StatusName
FROM dbo.Tickets t
JOIN dbo.Users      cu  ON cu.UserId      = t.CustomerId
LEFT JOIN dbo.Users ag  ON ag.UserId      = t.AssignedTo
JOIN dbo.Categories cat ON cat.CategoryId = t.CategoryId
JOIN dbo.Priorities pri ON pri.PriorityId = t.PriorityId
JOIN dbo.Statuses   st  ON st.StatusId    = t.StatusId
ORDER BY t.TicketId;

-- JOIN 2: conversation with author and role
SELECT tc.TicketId, t.Title, u.FullName AS Author, r.RoleName,
       tc.CommentText, tc.CreatedAt
FROM dbo.TicketComments tc
JOIN dbo.Tickets t ON t.TicketId = tc.TicketId
JOIN dbo.Users   u ON u.UserId   = tc.UserId
JOIN dbo.Roles   r ON r.RoleId   = u.RoleId
ORDER BY tc.TicketId, tc.CreatedAt;

-- JOIN 3: ticket counts by status
SELECT st.StatusName, COUNT(t.TicketId) AS TicketCount
FROM dbo.Statuses st
LEFT JOIN dbo.Tickets t ON t.StatusId = st.StatusId
GROUP BY st.StatusId, st.StatusName
ORDER BY st.StatusId;

-- JOIN 4: tickets raised per customer
SELECT u.UserId, u.FullName, COUNT(t.TicketId) AS TicketsRaised
FROM dbo.Users u
JOIN dbo.Roles r ON r.RoleId = u.RoleId AND r.RoleName='customer'
LEFT JOIN dbo.Tickets t ON t.CustomerId = u.UserId
GROUP BY u.UserId, u.FullName
ORDER BY TicketsRaised DESC;

-- JOIN 5: open workload per agent
SELECT u.UserId, u.FullName AS Agent, COUNT(t.TicketId) AS OpenTickets
FROM dbo.Users u
JOIN dbo.Roles r ON r.RoleId = u.RoleId AND r.RoleName='agent'
LEFT JOIN dbo.Tickets t ON t.AssignedTo = u.UserId AND t.StatusId IN (1,2,3)
GROUP BY u.UserId, u.FullName
ORDER BY OpenTickets DESC;

-- JOIN 6: full audit trail with resolved names
SELECT h.HistoryId, h.TicketId, t.Title, u.FullName AS ChangedBy,
       h.FieldName, h.OldValue, h.NewValue, h.ChangedAt
FROM dbo.TicketHistory h
JOIN dbo.Tickets t ON t.TicketId = h.TicketId
JOIN dbo.Users   u ON u.UserId   = h.UserId
ORDER BY h.TicketId, h.ChangedAt;
GO

/* =====================================================================
   7. VIEWS — 2 (minimum 2)
   ===================================================================== */
CREATE VIEW dbo.vw_OpenTickets AS
SELECT t.TicketId, t.Title,
       cu.FullName AS Customer,
       ISNULL(ag.FullName,'Unassigned') AS Assignee,
       cat.CategoryName, pri.PriorityName, st.StatusName,
       t.CreatedAt,
       DATEDIFF(DAY, t.CreatedAt, SYSUTCDATETIME()) AS AgeDays
FROM dbo.Tickets t
JOIN dbo.Users      cu  ON cu.UserId      = t.CustomerId
LEFT JOIN dbo.Users ag  ON ag.UserId      = t.AssignedTo
JOIN dbo.Categories cat ON cat.CategoryId = t.CategoryId
JOIN dbo.Priorities pri ON pri.PriorityId = t.PriorityId
JOIN dbo.Statuses   st  ON st.StatusId    = t.StatusId
WHERE st.StatusName IN ('Open','In Progress','Pending');
GO

CREATE VIEW dbo.vw_TicketSummary AS
SELECT st.StatusName, pri.PriorityName, COUNT(t.TicketId) AS TicketCount
FROM dbo.Tickets t
JOIN dbo.Statuses   st  ON st.StatusId    = t.StatusId
JOIN dbo.Priorities pri ON pri.PriorityId = t.PriorityId
GROUP BY st.StatusId, st.StatusName, pri.PriorityId, pri.PriorityName;
GO

/* =====================================================================
   8. STORED PROCEDURES — 2 (minimum 2), both transactional
   ===================================================================== */
CREATE PROCEDURE dbo.sp_CreateTicket
    @CustomerId  INT,
    @Title       NVARCHAR(150),
    @Description NVARCHAR(MAX),
    @CategoryId  INT,
    @PriorityId  INT,
    @NewTicketId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId=@CustomerId)
    BEGIN
        RAISERROR('Customer does not exist.',16,1); RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
            INSERT INTO dbo.Tickets
                (CustomerId,Title,Description,CategoryId,PriorityId,StatusId)
            VALUES (@CustomerId,@Title,@Description,@CategoryId,@PriorityId,1);

            SET @NewTicketId = SCOPE_IDENTITY();

            INSERT INTO dbo.TicketHistory
                (TicketId,UserId,FieldName,OldValue,NewValue)
            VALUES (@NewTicketId,@CustomerId,'created',NULL,'Open');
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE PROCEDURE dbo.sp_AssignTicket
    @TicketId     INT,
    @AssigneeId   INT,
    @ActingUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Users u
        JOIN dbo.Roles r ON r.RoleId=u.RoleId
        WHERE u.UserId=@AssigneeId AND r.RoleName='agent' AND u.IsActive=1)
    BEGIN
        RAISERROR('Assignee must be an active agent.',16,1); RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
            UPDATE dbo.Tickets
            SET AssignedTo=@AssigneeId, StatusId=2, UpdatedAt=SYSUTCDATETIME()
            WHERE TicketId=@TicketId;

            INSERT INTO dbo.TicketHistory
                (TicketId,UserId,FieldName,OldValue,NewValue)
            VALUES (@TicketId,@ActingUserId,'assigned_to',NULL,CAST(@AssigneeId AS NVARCHAR(100)));
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   9. DEMONSTRATION
   ===================================================================== */
DECLARE @Id INT;
EXEC dbo.sp_CreateTicket
     @CustomerId=4, @Title='Printer not detected',
     @Description='Network printer missing after driver update.',
     @CategoryId=3, @PriorityId=2, @NewTicketId=@Id OUTPUT;
SELECT @Id AS CreatedTicketId;

EXEC dbo.sp_AssignTicket @TicketId=@Id, @AssigneeId=2, @ActingUserId=1;

-- Rollback proof: assigning to a customer must fail and leave no trace
BEGIN TRY
    EXEC dbo.sp_AssignTicket @TicketId=@Id, @AssigneeId=4, @ActingUserId=1;
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS ExpectedRejection;
END CATCH

SELECT * FROM dbo.vw_OpenTickets;
SELECT * FROM dbo.vw_TicketSummary;
GO