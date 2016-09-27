/*
 
SQLUGChallenge2015
 
Author          : Sergey Klimkevich
Company         : ThomasCook
Version         : Domino
 
 
*/
 
SET NOCOUNT ON
GO
 
--/* Cleanup code
 
IF EXISTS(SELECT * FROM sys.services AS s WHERE s.name = 'SendService') DROP SERVICE SendService
IF EXISTS(SELECT * FROM sys.service_queues AS sq WHERE sq.name = 'SendQueue') DROP QUEUE SendQueue
GO
 
DECLARE @SQL NVARCHAR(MAX)
        ,@amount TINYINT = 16
 
WHILE @amount > 0
BEGIN
    SELECT
                @SQL = CONCAT('IF EXISTS(SELECT * FROM sys.services AS s WHERE s.name = ''ProcessCardFlowService',@amount,''') DROP SERVICE ProcessCardFlowService',@amount,';',CHAR(10))
                ,@SQL+= CONCAT('IF EXISTS(SELECT * FROM sys.service_queues AS sq WHERE sq.name = ''ProcessCardFlowQueue',@amount,''') DROP QUEUE ProcessCardFlowQueue',@amount,';',CHAR(10))
                ,@SQL+= CONCAT('IF OBJECT_ID(''dbo.ProcessCardFlowActivation',@amount,''') IS NOT NULL DROP PROCEDURE dbo.ProcessCardFlowActivation',@amount,';',CHAR(10))
                ,@amount -=1
        EXEC (@SQL)
 
END    
GO
 
 
IF OBJECT_ID('dbo.ProcessCardFlow') IS NOT NULL DROP PROCEDURE dbo.ProcessCardFlow
IF OBJECT_ID('dbo.[ProcessCardFlowWorker]') IS NOT NULL DROP PROCEDURE dbo.[ProcessCardFlowWorker]
IF OBJECT_ID('dbo.WaitForBackgroundProcessToFinish') IS NOT NULL DROP PROCEDURE dbo.WaitForBackgroundProcessToFinish
IF OBJECT_ID('dbo.PopulateSplitList') IS NOT NULL DROP PROCEDURE dbo.PopulateSplitList
IF OBJECT_ID('dbo.MainRun') IS NOT NULL DROP PROCEDURE dbo.MainRun
GO
 
 
IF EXISTS(SELECT * FROM sys.service_contracts AS sc WHERE sc.name = '//SQLugChallenge2015/Contract') DROP CONTRACT [//SQLugChallenge2015/Contract]
IF EXISTS(SELECT * FROM sys.service_message_types AS smt WHERE smt.name = '//SQLugChallenge2015/StartBackgroundThread') DROP MESSAGE TYPE [//SQLugChallenge2015/StartBackgroundThread]
IF EXISTS(SELECT * FROM sys.service_message_types AS smt WHERE smt.name = '//SQLugChallenge2015/StartProcessingCardFlow') DROP MESSAGE TYPE [//SQLugChallenge2015/StartProcessingCardFlow]
 
 
IF OBJECT_ID('dbo.StatusCards', 'U') IS NOT NULL DROP TABLE dbo.StatusCards
IF OBJECT_ID('dbo.SplitList', 'U') IS NOT NULL DROP TABLE dbo.SplitList
IF OBJECT_ID('dbo.DlgHandle', 'U') IS NOT NULL DROP TABLE dbo.DlgHandle
IF OBJECT_ID('dbo.ProcessCardFlowResult', 'U') IS NOT NULL DROP TABLE dbo.ProcessCardFlowResult
 
 
IF EXISTS(SELECT * FROM sys.types WHERE name = 'CardFlowType') DROP TYPE dbo.CardFlowType
 
--*/
 
 
/******************************************************************************************************
--*****************************************************************************************************
-- Create Objects
--*****************************************************************************************************
--*****************************************************************************************************/
 
-- ALTER DATABASE CURRENT SET NEW_BROKER WITH ROLLBACK IMMEDIATE
 
CREATE MESSAGE TYPE [//SQLugChallenge2015/StartBackgroundThread] VALIDATION = NONE
CREATE MESSAGE TYPE [//SQLugChallenge2015/StartProcessingCardFlow]
 
 
CREATE CONTRACT [//SQLugChallenge2015/Contract]
(
[//SQLugChallenge2015/StartBackgroundThread] SENT BY INITIATOR,
[//SQLugChallenge2015/StartProcessingCardFlow] SENT BY INITIATOR
)
GO
 
CREATE TYPE dbo.CardFlowType AS TABLE(
CardID INT NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 262144)
,RankPoint TINYINT NOT NULL
) WITH (MEMORY_OPTIMIZED = ON)
GO
 
 
CREATE TABLE dbo.StatusCards (
        [CardID] INT NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1048576), --4194304
        [STATUS] CHAR(1) NOT NULL
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY)
GO
 
 
CREATE TABLE dbo.ProcessCardFlowResult (
        ListID INT NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 32),
        RunningSum TINYINT NOT NULL,
        MayWithdraw10Points BIT NOT NULL,
        CardNo TINYINT NOT NULL,
        B INT NOT NULL,
        L INT NOT NULL,
        S INT NOT NULL,
        W INT NOT NULL
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY)
 
INSERT dbo.ProcessCardFlowResult (ListID, RunningSum, MayWithdraw10Points, CardNo, B, L, S, W)
        VALUES (0, 0, 0, 1, 0, 0, 0, 0);
GO
 
 
CREATE TABLE dbo.SplitList (
        [id] INT NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 256),
        [from_cid] INT NOT NULL,
        [to_cid] INT NOT NULL,
        [NextProcessDlgHandle] UNIQUEIDENTIFIER NULL
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY)
GO
 
 
CREATE TABLE dbo.DlgHandle (
        [ListID] TINYINT NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 64),
        [DlgHandle] UNIQUEIDENTIFIER NULL
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY)
GO
 
 
 
 
 
CREATE PROCEDURE dbo.WaitForBackgroundProcessToFinish
(
        @NumberOfUpdateThreads TINYINT
)
AS
BEGIN
        SET NOCOUNT ON;
 
        DECLARE @DlgHandle UNIQUEIDENTIFIER,
                        @MsgType SYSNAME,
                        @Msg VARBINARY(MAX),
                        @x TINYINT = 0
 
        WHILE 1=1
        BEGIN
                BEGIN TRANSACTION;
                WAITFOR
                (
                RECEIVE TOP (1)
                @DlgHandle = conversation_handle,
                @MsgType = message_type_name,
                @Msg = message_body
                FROM dbo.[SendQueue]
                ), TIMEOUT 30000;
 
                IF @DlgHandle IS NOT NULL
                BEGIN
 
                        IF @MsgType = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
                        BEGIN
                                END CONVERSATION @DlgHandle;
 
                                SET @x += 1
 
                                IF @x = @NumberOfUpdateThreads
                                BEGIN
                                        TRUNCATE TABLE dbo.DealerStatus
                                        DECLARE
                                                @_B INT,
                                                @_L INT,
                                                @_S INT,
                                                @_W INT
 
                                        SELECT                         
                                                @_B = pcfr.B,
                                                @_L = pcfr.L,
                                                @_S = pcfr.S,
                                                @_W = pcfr.W
                                        FROM ProcessCardFlowResult pcfr
                                        WHERE pcfr.ListID = @NumberOfUpdateThreads
 
                                        INSERT dbo.DealerStatus ([STATUS], Deals)
                                        VALUES
                                                ('B', @_B),
                                                ('L', @_L),
                                                ('S', @_S),
                                                ('W', @_W)
 
                        COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON);
                                        BREAK;
                END
                        END
                        ELSE
                        IF @MsgType = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
                        BEGIN
                                END CONVERSATION @DlgHandle;
                                DECLARE @error INT;
                                DECLARE @description NVARCHAR(4000);
                                WITH XMLNAMESPACES ('http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS ssb)
                                SELECT
                                        @error = CAST(@Msg AS XML).VALUE(
                                        '(//ssb:Error/ssb:Code)[1]', 'INT'),
                                        @description = CAST(@Msg AS XML).VALUE(
                                        '(//ssb:Error/ssb:Description)[1]', 'NVARCHAR(4000)')
                                RAISERROR (N'Received error Code:%i Description:"%s"',
                                16, 1, @error, @description) WITH LOG;
                        END
                END
                COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON);
    END -- while
END
GO
 
 
 
 
 
 
 
 
 
CREATE PROCEDURE dbo.ProcessCardFlow
(
        @ListID INT,
        @flow dbo.CardFlowType READONLY
)
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english', DELAYED_DURABILITY = ON)
        DECLARE @RankPoint TINYINT = 0,
                        @CurrentStatus CHAR(1) = ' ',
                        @from_CardID INT,
                        @to_CardID INT,
                        @RunningSum TINYINT,
                        @MayWithdraw10Points BIT,
                        @CardNo TINYINT,
                        @_B INT,
                        @_L INT,
                        @_S INT,
                        @_W INT
 
        SELECT
                @RunningSum = RunningSum,
                @MayWithdraw10Points = MayWithdraw10Points,
                @CardNo = CardNo,
                @_B = B,
                @_L = L,
                @_S = S,
                @_W = W
        FROM dbo.ProcessCardFlowResult pcfr
                WHERE pcfr.ListID = @ListID - 1
 
        SELECT
                @from_CardID = sl.from_cid,
                @to_CardID = sl.to_cid
        FROM dbo.SplitList sl
                WHERE sl.id = @ListID
 
        WHILE @from_CardID <= @to_CardID
        BEGIN
 
                SELECT
                        @RankPoint = c.RankPoint
                FROM @flow c
                WHERE
                        c.CardID = @from_CardID
 
                IF @RankPoint > 10
                        SET @RankPoint = 10
                ELSE
                IF @RankPoint = 1
                        IF @MayWithdraw10Points = 0
                                SELECT
                                        @RankPoint = 11
                                        ,@MayWithdraw10Points = 1
 
                SET @RunningSum += @RankPoint
 
                IF @RunningSum > 21
                        AND @MayWithdraw10Points = 1
                        SELECT
                                @RunningSum -= 10
                                ,@MayWithdraw10Points = 0
 
                IF @RunningSum > 16
                BEGIN
                        IF (@RunningSum = 21)
                                IF (@CardNo = 2)
                                        SELECT @CurrentStatus = 'B', @_B += 1
                                ELSE
                                        SELECT @CurrentStatus = 'W', @_W += 1
                        ELSE IF @RunningSum > 21
                                SELECT @CurrentStatus = 'L', @_L += 1
                        ELSE
                                SELECT @CurrentStatus = 'S', @_S += 1
 
                        INSERT dbo.StatusCards
                                VALUES (@from_CardID, @CurrentStatus)
 
                        SELECT
                                @RunningSum = 0
                                ,@CardNo = 1
                                ,@MayWithdraw10Points = 0
                END
                ELSE
                        SET @CardNo += 1
 
                SET @from_CardID += 1
        END --while
 
        INSERT dbo.ProcessCardFlowResult (ListID, RunningSum, MayWithdraw10Points, CardNo, B, L, S, W)
                SELECT
                        @ListID,
                        @RunningSum,
                        @MayWithdraw10Points,
                        @CardNo,
                        @_B,
                        @_L,
                        @_S,
                        @_W
 
END --proc dbo.ProcessCardFlow
GO
 
 
 
 
 
 
 
 
CREATE PROCEDURE dbo.[ProcessCardFlowWorker]
(
        @wid TINYINT
)
AS
BEGIN
        SET NOCOUNT ON;
 
 
        DECLARE @DlgHandle UNIQUEIDENTIFIER,
                        @MsgType SYSNAME,
                        @error_number INT,
                        @error_message NVARCHAR(4000),
                        @xact_state INT,
                        @ParmDefinition NVARCHAR(4000),
                        @SQLString NVARCHAR(4000),
                        @from_CardID INT,
                        @to_CardID INT,
                        @flow dbo.CardFlowType,
                        @NextWorkerDlgHandle UNIQUEIDENTIFIER
 
        WHILE 1=1
        BEGIN
                IF NOT (@DlgHandle IS NOT NULL AND @wid = 1)
                BEGIN
                        SELECT @SQLString = CONCAT('
                        WAITFOR
                        (
                                RECEIVE TOP (1) @DlgHandleOUT = conversation_handle,
                                @MsgTypeOUT = message_type_name
                                FROM dbo.[ProcessCardFlowQueue',@wid,']
                        ), TIMEOUT 10000;
                        ')
                        ,@ParmDefinition = '@DlgHandleOUT UNIQUEIDENTIFIER OUTPUT,@MsgTypeOUT SYSNAME OUTPUT'
 
                        EXECUTE sp_executesql @SQLString, @ParmDefinition, @DlgHandleOUT = @DlgHandle OUTPUT, @MsgTypeOUT = @MsgType OUTPUT
 
        END
 
                IF @DlgHandle IS NULL BREAK
 
                IF @MsgType = N'//SQLugChallenge2015/StartBackgroundThread'
                BEGIN
 
                        SELECT
                                @from_CardID = sl.from_cid,
                                @to_CardID = sl.to_cid,
                                @NextWorkerDlgHandle = sl.NextProcessDlgHandle
                        FROM dbo.SplitList sl
                        WHERE sl.id=@wid
       
                        IF @NextWorkerDlgHandle IS NOT NULL
                        BEGIN
                                IF @wid > 1
                                BEGIN
                                        WAITFOR DELAY '00:00:00.01'
                                END
 
                ;SEND ON CONVERSATION @NextWorkerDlgHandle MESSAGE TYPE [//SQLugChallenge2015/StartBackgroundThread]
            END
 
                        BEGIN TRANSACTION
         
                                INSERT @flow (CardID, RankPoint)
                                SELECT ch.CardID, ch.[Rank]
                                FROM dbo.CardHistory ch WITH (PAGLOCK)
                                WHERE ch.CardID >= @from_CardID AND ch.CardID <= @to_CardID
 
                        COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON)
 
                        IF @wid = 1
                        BEGIN
                                SET @MsgType = N'//SQLugChallenge2015/StartProcessingCardFlow'
                        END
 
                END
                ELSE
                IF @MsgType = N'//SQLugChallenge2015/StartProcessingCardFlow'
                BEGIN
       
                        BEGIN TRANSACTION
 
                                EXEC dbo.ProcessCardFlow @wid, @flow
 
                                IF @NextWorkerDlgHandle IS NOT NULL
                                BEGIN
                                        ;SEND ON CONVERSATION @NextWorkerDlgHandle MESSAGE TYPE [//SQLugChallenge2015/StartProcessingCardFlow];
                                END
 
                        COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON)
 
                        ------------------------------------------------------
                        -- UpdateStatus
                        ------------------------------------------------------
                        BEGIN TRANSACTION
 
                                UPDATE h
                                SET STATUS = u.[STATUS]
                                FROM dbo.StatusCards u
                                JOIN dbo.CardHistory h WITH (PAGLOCK)
                                        ON h.CardID = u.CardID
                                WHERE u.CardID >= @from_CardID
                                AND u.CardID < @to_CardID
 
                                IF @NextWorkerDlgHandle IS NULL
                                BEGIN
                                        UPDATE h
                                        SET STATUS = u.[STATUS]
                                        FROM dbo.SplitList sl
                                        JOIN dbo.StatusCards u
                                                ON sl.to_cid = u.CardID
                                        JOIN dbo.CardHistory h
                                                ON h.CardID = u.CardID
                                END
 
                                END CONVERSATION @DlgHandle
 
                        COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON)            
 
                        BREAK
                       
                END --IF @MsgType = N'//SQLugChallenge2015/StartProcessingCardFlow'
 
    END --while
 
END --dbo.[ProcessCardFlowWorker]
 
 
GO
 
 
 
 
 
 
 
 
CREATE PROCEDURE dbo.PopulateSplitList
(
        @tot INT,
        @nob TINYINT OUTPUT
)
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english', DELAYED_DURABILITY = ON)
 
        DECLARE @batch_size INT,
                        @NextProcessDlgHandle UNIQUEIDENTIFIER,
                        @x TINYINT = 1
 
        SELECT @nob = 16, @batch_size = @tot / @nob
 
        IF @tot < 84032
        BEGIN
        INSERT dbo.SplitList (id, from_cid, to_cid)
                SELECT 1, 1, @tot
 
                SELECT @nob = 1
    END
        ELSE
        BEGIN
                SELECT @batch_size = @batch_size + 506 - @batch_size%506
       
                WHILE (@x - 1) * @batch_size + @batch_size < @tot
                BEGIN
                SELECT @NextProcessDlgHandle = dh.DlgHandle FROM dbo.DlgHandle AS dh WHERE dh.ListID = @x + 1
 
                INSERT dbo.SplitList (id, from_cid, to_cid, NextProcessDlgHandle)
                        SELECT  @x,
                                        (@x - 1) * @batch_size + 1,
                                        (@x - 1) * @batch_size + @batch_size,
                                        @NextProcessDlgHandle
 
                        SET @x += 1
                END
 
                INSERT dbo.SplitList (id, from_cid, to_cid)
                SELECT  @x,
                                (@x - 1) * @batch_size + 1,
                                @tot    
        END
END
GO
 
 
 
 
 
CREATE QUEUE [dbo].[SendQueue]
CREATE SERVICE [SendService] ON QUEUE [dbo].[SendQueue];
GO
 
 
 
DECLARE @SQL NVARCHAR(MAX) = '', @amount TINYINT = 16
 
WHILE @amount > 0
BEGIN
        SELECT
                @SQL = CONCAT('CREATE PROCEDURE dbo.[ProcessCardFlowActivation',@amount,'] AS EXEC dbo.[ProcessCardFlowWorker] ',@amount,';',CHAR(10))
        ,@amount -=1
        EXEC (@SQL)
 
END
GO
 
 
DECLARE @SQL NVARCHAR(MAX)
        ,@amount TINYINT = 16
        ,@x INT = 1
 
WHILE @x <= @amount
BEGIN
    SELECT
                @SQL = CONCAT('DECLARE @ProcessCardFlowDlgHandle UNIQUEIDENTIFIER;', CHAR(10))
                ,@SQL += CONCAT('CREATE QUEUE [dbo].[ProcessCardFlowQueue',@x,'] WITH ACTIVATION (STATUS = ON, MAX_QUEUE_READERS = 1, PROCEDURE_NAME = dbo.[ProcessCardFlowActivation',@x,'],EXECUTE AS OWNER);',CHAR(10))
                ,@SQL += CONCAT('CREATE SERVICE [ProcessCardFlowService',@x,'] ON QUEUE [dbo].[ProcessCardFlowQueue',@x,'] ([//SQLugChallenge2015/Contract]);',CHAR(10))
                ,@SQL += CONCAT('BEGIN DIALOG @ProcessCardFlowDlgHandle FROM SERVICE [SendService] TO SERVICE ''ProcessCardFlowService',@x,''' ON CONTRACT [//SQLugChallenge2015/Contract] WITH ENCRYPTION = OFF;',CHAR(10))
                ,@SQL += CONCAT('INSERT dbo.DlgHandle (ListID, DlgHandle) VALUES (',@x,',@ProcessCardFlowDlgHandle);',CHAR(10))
                ,@x +=1
        EXEC(@SQL)
END
GO
 
 
 
 
 
CREATE PROCEDURE dbo.MainRun
AS
BEGIN
        SET NOCOUNT ON;
 
        DECLARE @tot INT,
                        @nob TINYINT
       
        BEGIN TRANSACTION
 
        SELECT TOP (1) @tot = ch.CardID
        FROM dbo.CardHistory AS ch
        ORDER BY ch.CardID DESC
 
        EXEC dbo.PopulateSplitList      @tot = @tot,
                                                                @nob = @nob OUT
 
        DECLARE @FirstProcessCardFlowDlgHandle UNIQUEIDENTIFIER
 
        SELECT
                @FirstProcessCardFlowDlgHandle=dh.DlgHandle
        FROM dbo.DlgHandle dh
        WHERE dh.ListID = 1
 
        ;SEND ON CONVERSATION @FirstProcessCardFlowDlgHandle MESSAGE TYPE [//SQLugChallenge2015/StartBackgroundThread]
 
        COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON)  
 
        EXEC dbo.WaitForBackgroundProcessToFinish @NumberOfUpdateThreads = @nob
 
END
GO