/*============================================================================
  File:     sp_SQLskillsAbortedTransactions.sql
  
  Summary:  This script cracks the transaction log and shows which
            transactions were rolled back after a crash
  
  SQL Server Versions: 2012 onwards
------------------------------------------------------------------------------
  Written by Paul S. Randal, SQLskills.com
  
  (c) 2017, SQLskills.com. All rights reserved.
  
  For more scripts and sample code, check out 
    http://www.SQLskills.com
  
  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
    
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/
  
  -- And there’s a trick you need to use: to get the fn_dblog function to read log records from before the log clears 
  -- (by the checkpoints that crash recovery does, in the simple recovery model, or by log backups, in other recovery models), 
  
  -- you need to enable trace flag 2537. 
  
  -- Now, if do all this too long after crash recovery runs, the log may have overwritten 
  -- itself and so you won’t be able to get the info you need, but if you’re taking log backups, you could restore a copy of the 
  -- database to the point just after crash recovery has finished, and then do the investigation.

-- Source and full blog.
-- http://www.sqlskills.com/blogs/paul/code-to-show-rolled-back-transactions-after-a-crash/
  
  
USE [master];
GO
  
IF OBJECT_ID (N'sp_SQLskillsAbortedTransactions') IS NOT NULL
    DROP PROCEDURE [sp_SQLskillsAbortedTransactions];
GO
  
CREATE PROCEDURE sp_SQLskillsAbortedTransactions
AS
BEGIN
    SET NOCOUNT ON;
 
    DBCC TRACEON (2537);
  
    DECLARE @BootTime   DATETIME;
    DECLARE @XactID     CHAR (13);
 
    SELECT @BootTime = [sqlserver_start_time] FROM sys.dm_os_sys_info;
 
    IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
        WHERE [name] = N'##SQLskills_Log_Analysis')
        DROP TABLE [##SQLskills_Log_Analysis];
 
    -- Get the list of started and rolled back transactions from the log
    SELECT
        [Begin Time],
        [Transaction Name],
        SUSER_SNAME ([Transaction SID]) AS [Started By],
        [Transaction ID],
        [End Time],
        0 AS [RolledBackAfterCrash],
        [Operation]
    INTO ##SQLskills_Log_Analysis
    FROM fn_dblog (NULL, NULL)
    WHERE ([Operation] = 'LOP_BEGIN_XACT' AND [Begin Time] < @BootTime) OR ([Operation] = 'LOP_ABORT_XACT' AND [End Time] > @BootTime);
 
    DECLARE [LogAnalysis] CURSOR FAST_FORWARD FOR
    SELECT
        [Transaction ID]
    FROM
        ##SQLskills_Log_Analysis;
  
    OPEN [LogAnalysis];
  
    FETCH NEXT FROM [LogAnalysis] INTO @XactID;
  
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (
            SELECT [End Time] FROM ##SQLskills_Log_Analysis
            WHERE [Operation] = 'LOP_ABORT_XACT' AND [Transaction ID] = @XactID)
        UPDATE ##SQLskills_Log_Analysis SET [RolledBackAfterCrash] = 1
            WHERE [Transaction ID] = @XactID
            AND [Operation] = 'LOP_BEGIN_XACT';
 
        FETCH NEXT FROM [LogAnalysis] INTO @XactID;
    END;
  
    CLOSE [LogAnalysis];
    DEALLOCATE [LogAnalysis];
  
    SELECT
        [Begin Time],
        [Transaction Name],
        [Started By],
        [Transaction ID]
    FROM ##SQLskills_Log_Analysis
    WHERE [RolledBackAfterCrash] = 1;
  
    DBCC TRACEOFF (2537);
 
    DROP TABLE ##SQLskills_Log_Analysis;
END
GO
  
EXEC sys.sp_MS_marksystemobject [sp_SQLskillsAbortedTransactions];
GO
  
-- USE [Company]; EXEC sp_SQLskillsAbortedTransactions;