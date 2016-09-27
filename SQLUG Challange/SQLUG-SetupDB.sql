SET NOEXEC Off
GO
 
USE [master]
GO
 
IF DB_ID('u5') IS NOT NULL BEGIN
        ALTER DATABASE [u5] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
        DROP DATABASE [u5]
END
GO
 
 
/* Comment this line for restore only
 
RESTORE DATABASE u5 FROM DISK =N'C:\temp\u5_full.bak' WITH FILE = 1 ,STATS = 5
GO
 
USE u5
GO
 
 
IF (
                SELECT
                        is_broker_enabled
                FROM sys.databases
                WHERE name = DB_NAME()
        )
        = 0
BEGIN
        ALTER DATABASE CURRENT SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        ALTER DATABASE CURRENT SET ENABLE_BROKER;
        ALTER DATABASE CURRENT SET MULTI_USER;
END
GO
 
--DECLARE @a CHAR(1) SELECT @a = ch.[Status] FROM dbo.CardHistory AS ch
 
SET NOEXEC ON
GO
 
 
--*/
USE [master]
GO
 
CREATE DATABASE [u5]
 CONTAINMENT = NONE
 ON  PRIMARY
( NAME = N'u5', FILENAME = N'C:\DATA\u5.mdf' , SIZE = 1GB , MAXSIZE = UNLIMITED, FILEGROWTH = 200MB),
 FILEGROUP [MemoryOptimized] CONTAINS MEMORY_OPTIMIZED_DATA  DEFAULT
( NAME = N'u5_mem', FILENAME = N'C:\DATA\u5_mem' , MAXSIZE = UNLIMITED)
 LOG ON
( NAME = N'u5_log', FILENAME = N'C:\DATA\u5_log.ldf' , SIZE = 500MB , MAXSIZE = 2048GB , FILEGROWTH = 100MB)
 COLLATE Finnish_Swedish_100_BIN2
GO
ALTER DATABASE [u5] SET COMPATIBILITY_LEVEL = 120 -- 130 works too
GO
ALTER DATABASE [u5] SET ANSI_NULL_DEFAULT OFF
GO
ALTER DATABASE [u5] SET ANSI_NULLS OFF
GO
ALTER DATABASE [u5] SET ANSI_PADDING OFF
GO
ALTER DATABASE [u5] SET ANSI_WARNINGS OFF
GO
ALTER DATABASE [u5] SET ARITHABORT OFF
GO
ALTER DATABASE [u5] SET AUTO_CLOSE OFF
GO
ALTER DATABASE [u5] SET AUTO_SHRINK OFF
GO
ALTER DATABASE [u5] SET AUTO_CREATE_STATISTICS ON
GO
ALTER DATABASE [u5] SET AUTO_UPDATE_STATISTICS ON
GO
ALTER DATABASE [u5] SET CURSOR_CLOSE_ON_COMMIT OFF
GO
ALTER DATABASE [u5] SET CURSOR_DEFAULT  GLOBAL
GO
ALTER DATABASE [u5] SET CONCAT_NULL_YIELDS_NULL OFF
GO
ALTER DATABASE [u5] SET NUMERIC_ROUNDABORT OFF
GO
ALTER DATABASE [u5] SET QUOTED_IDENTIFIER OFF
GO
ALTER DATABASE [u5] SET RECURSIVE_TRIGGERS OFF
GO
ALTER DATABASE [u5] SET ENABLE_BROKER;
GO
ALTER DATABASE [u5] SET AUTO_UPDATE_STATISTICS_ASYNC OFF
GO
ALTER DATABASE [u5] SET DATE_CORRELATION_OPTIMIZATION OFF
GO
ALTER DATABASE [u5] SET PARAMETERIZATION SIMPLE
GO
ALTER DATABASE [u5] SET READ_COMMITTED_SNAPSHOT OFF
GO
ALTER DATABASE [u5] SET  READ_WRITE
GO
ALTER DATABASE [u5] SET RECOVERY SIMPLE
GO
ALTER DATABASE [u5] SET  MULTI_USER
GO
ALTER DATABASE [u5] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [u5] SET TARGET_RECOVERY_TIME = 0 SECONDS
GO
ALTER DATABASE [u5] SET DELAYED_DURABILITY = ALLOWED
GO
USE [u5]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [u5] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
 
 
ALTER AUTHORIZATION ON DATABASE::u5 TO sa;
 
 
 
USE u5
GO
 
 
-- Tillåt delayed durability
ALTER DATABASE u5 SET DELAYED_DURABILITY = ALLOWED WITH NO_WAIT
GO     
-- Förebygg vissa problem med transaction isolation levels
ALTER DATABASE u5 SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = ON
GO
 
 
-- Prevent unwanted resultsets back to client
SET NOCOUNT ON;
 
-- Drop dbo.CardHistory table if aready present
IF OBJECT_ID('dbo.CardHistory', 'U') IS NOT NULL
        DROP TABLE      dbo.CardHistory;
GO
 
-- Create dbo.CardHistory table
CREATE TABLE    dbo.CardHistory
                (
                        CardID INT IDENTITY(1, 1),
                        CONSTRAINT PK_CardHistory PRIMARY KEY CLUSTERED
                        (
                                CardID
                        ),
                        [Rank] TINYINT NOT NULL,
                        Suit CHAR(1) NOT NULL,
                        [STATUS] CHAR(1) NOT NULL
                );
 
-- Drop dbo.DealerStatus table if aready present
IF OBJECT_ID('dbo.DealerStatus', 'U') IS NOT NULL
        DROP TABLE      dbo.DealerStatus;
GO
 
-- Create dbo.DealerStatus table
CREATE TABLE    dbo.DealerStatus
                (
                        [STATUS] CHAR(1) NOT NULL,
                        CONSTRAINT PK_DealerStatus PRIMARY KEY CLUSTERED
                        (
                                [STATUS]
                        ),
                        Deals INT NOT NULL
                );
 
-- Prepare iteration of 2500 shuffles of 8 decks.
DECLARE @Shuffle SMALLINT = 1;
 
CREATE TABLE    #Values
                (
                        VALUE TINYINT PRIMARY KEY CLUSTERED
                );
 
INSERT  #Values
        (
                VALUE
        )
VALUES  (1),
        (2),
        (3),
        (4),
        (5),
        (6),
        (7),
        (8),
        (9),
        (10),
        (11),
        (12),
        (13);
 
-- Iterate
WHILE @Shuffle <= 2500
        BEGIN
                -- Populate dbo.CardHistory table
                INSERT          dbo.CardHistory
                                (
                                        [Rank],
                                        Suit,
                                        [STATUS]
                                )
                SELECT          r.VALUE AS [Rank],
                                CASE s.VALUE
                                        WHEN 1 THEN 'H'
                                        WHEN 2 THEN 'S'
                                        WHEN 3 THEN 'D'
                                        ELSE 'C'
                                END AS Suit,
                                ' ' AS [STATUS]
                FROM            #Values AS r                            -- Rank
                INNER JOIN      #Values AS s ON s.VALUE BETWEEN 1 AND 4 -- Suit
                INNER JOIN      #Values AS d ON d.VALUE BETWEEN 1 AND 8 -- Deck
                ORDER BY        NEWID();
 
                -- Next shuffle
                SET     @Shuffle += 1;
        END;
 
-- Clean up
DROP TABLE      #Values;
GO
 
 
 
 
 
/*
USE master
GO
 
BACKUP DATABASE [u5] TO  DISK = N'C:\temp\u5_full.bak' WITH NOFORMAT, INIT,
NAME = N'u5-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
 
--*/
 
SET NOEXEC Off