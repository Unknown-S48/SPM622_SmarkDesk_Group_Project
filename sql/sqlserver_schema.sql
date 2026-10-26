-- Microsoft SQL Server 2022+ | Execute in SSMS on a test instance.
-- Schema equivalent to the SQLite database used by the local demo.
IF DB_ID(N'CustomerSupportDB') IS NULL CREATE DATABASE CustomerSupportDB;
GO
USE CustomerSupportDB;
GO
IF OBJECT_ID('dbo.Users','U') IS NULL
CREATE TABLE dbo.Users (
 UserID INT IDENTITY(1,1) PRIMARY KEY,
 FullName NVARCHAR(100) NOT NULL,
 Email NVARCHAR(200) NOT NULL UNIQUE,
 PasswordHash NVARCHAR(255) NOT NULL,
 UserRole NVARCHAR(20) NOT NULL DEFAULT 'customer',
 CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_Users_Role CHECK(UserRole IN ('customer','agent','admin'))
);
GO
IF OBJECT_ID('dbo.Tickets','U') IS NULL
CREATE TABLE dbo.Tickets (
 TicketID INT IDENTITY(1,1) PRIMARY KEY,
 CustomerID INT NOT NULL REFERENCES dbo.Users(UserID),
 AssignedTo INT NULL REFERENCES dbo.Users(UserID),
 Title NVARCHAR(150) NOT NULL,
 Description NVARCHAR(MAX) NOT NULL,
 Category NVARCHAR(30) NOT NULL,
 Priority NVARCHAR(20) NOT NULL DEFAULT 'Medium',
 TicketStatus NVARCHAR(30) NOT NULL DEFAULT 'Open',
 CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
 UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_Tickets_Category CHECK(Category IN ('Account','Billing','Technical','Product','General')),
 CONSTRAINT CK_Tickets_Priority CHECK(Priority IN ('Low','Medium','High','Critical')),
 CONSTRAINT CK_Tickets_Status CHECK(TicketStatus IN ('Open','In Progress','Pending','Resolved','Closed'))
);
GO
IF OBJECT_ID('dbo.TicketComments','U') IS NULL
CREATE TABLE dbo.TicketComments (
 CommentID INT IDENTITY(1,1) PRIMARY KEY,
 TicketID INT NOT NULL REFERENCES dbo.Tickets(TicketID) ON DELETE CASCADE,
 UserID INT NOT NULL REFERENCES dbo.Users(UserID),
 CommentText NVARCHAR(3000) NOT NULL,
 CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Tickets_Customer' AND object_id=OBJECT_ID('dbo.Tickets'))
 CREATE INDEX IX_Tickets_Customer ON dbo.Tickets(CustomerID);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Tickets_Status' AND object_id=OBJECT_ID('dbo.Tickets'))
 CREATE INDEX IX_Tickets_Status ON dbo.Tickets(TicketStatus);
GO
-- Reporting queries:
SELECT TicketStatus, COUNT(*) AS TotalTickets FROM dbo.Tickets GROUP BY TicketStatus;
SELECT Priority, COUNT(*) AS TotalTickets FROM dbo.Tickets GROUP BY Priority;
SELECT TOP (10) TicketID, Title, TicketStatus, Priority, CreatedAt FROM dbo.Tickets ORDER BY CreatedAt DESC;
GO
