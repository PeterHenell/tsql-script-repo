-- http://rusanu.com/2006/10/16/writing-service-broker-procedures/
CREATE QUEUE [Initiator];
CREATE QUEUE [Target];
CREATE SERVICE [Initiator] ON QUEUE [Initiator];
CREATE SERVICE [Target] ON QUEUE [Target] ([DEFAULT]);


GO

GO
CREATE FUNCTION [BinaryMarhsalPayload] (
    @dateTime DATETIME,
    @payload VARBINARY(MAX),
    @user NVARCHAR(256))
    RETURNS VARBINARY(MAX)
AS
BEGIN
DECLARE @marshaledPayload VARBINARY(MAX);
DECLARE @payloadLength BIGINT;
DECLARE @userLength INT;
SELECT @payloadLength = LEN(@payload), @userLength = LEN(@user) * 2; -- wchar_t
    SELECT @marshaledPayload = CAST(@dateTime AS VARBINARY(8)) +
                               CAST(@payloadLength AS VARBINARY(MAX)) + @payload +
                               CAST(@userLength AS VARBINARY(MAX)) + CAST(@user AS VARBINARY(MAX));
RETURN (@marshaledPayload);
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE NAME = N'BinaryUnmarhsalPayload')
DROP FUNCTION [BinaryUnmarhsalPayload]
GO
CREATE FUNCTION [BinaryUnmarhsalPayload] (@message_body VARBINARY(MAX))
    RETURNS TABLE RETURN 
    
    SELECT dt AS [DateTime], payload, username AS [User]
    FROM (VALUES (
                 CAST(SUBSTRING(@message_body, 1, 8) AS DATETIME), 
                 CAST(SUBSTRING(@message_body, 9, 8) AS BIGINT) -- payloadlength
                 ) ) input(dt, payloadLength)
    CROSS APPLY (SELECT CAST(SUBSTRING(@message_body, payloadLength + 17, 4) AS INT)) u(userlength) -- userlength
    CROSS APPLY (
            SELECT SUBSTRING(@message_body, 17, payloadLength),
                   CAST(SUBSTRING(@message_body, payloadLength + 21, userLength) AS NVARCHAR(256))
                 ) AS parsed(payload, username) 
GO

IF EXISTS(SELECT * FROM sys.tables WHERE NAME = N'PayloadData')
DROP TABLE [PayloadData];
GO
CREATE TABLE [PayloadData] (
    [Id] INT NOT NULL IDENTITY,
    [DateTime] DATETIME,
    [Payload] NVARCHAR(MAX),
    [User] NVARCHAR(256));
GO
IF EXISTS(SELECT * FROM sys.procedures WHERE NAME = N'RowsetBinaryDatagram')
    DROP PROCEDURE [RowsetBinaryDatagram];
GO
CREATE PROCEDURE [RowsetBinaryDatagram]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tableMessages TABLE (
        queuing_order BIGINT,
        conversation_handle UNIQUEIDENTIFIER,
        message_type_name SYSNAME,
        message_body VARBINARY(MAX)
    );
    WHILE (1=1)
    BEGIN
        BEGIN TRANSACTION;
        WAITFOR(RECEIVE
            queuing_order,
            conversation_handle,
            message_type_name,
            message_body
        FROM [Target]
        INTO @tableMessages), TIMEOUT 1000;
        IF (@@ROWCOUNT = 0)
        BEGIN
            COMMIT;
            BREAK;
        END

        -- Rowset based datagram processing:
        -- Unmarshal the binary result into the table
        INSERT INTO [PayloadData] ([DateTime], [Payload], [User])
        SELECT [DateTime], [Payload], [User]
        FROM @tableMessages
        CROSS APPLY dbo.[BinaryUnmarhsalPayload](message_body)
        WHERE message_type_name = 'DEFAULT'
        OPTION(RECOMPILE);
    
        COMMIT;
        DELETE FROM @tableMessages;
    END
END
GO


-- This procedure loads the test queue qith the
-- number of messages and conversations passed in
--
CREATE PROCEDURE LoadQueueReceivePerfBlog
    @conversationCount INT,
    @messagesPerConversation INT,
    @payload VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @batchCount INT;
    SELECT @batchCount = 0;
    DECLARE @h UNIQUEIDENTIFIER;
    BEGIN TRANSACTION;
    WHILE @conversationCount > 0
    BEGIN
        BEGIN DIALOG CONVERSATION @h
        FROM SERVICE [Initiator] TO SERVICE N'Target', 'current database' WITH ENCRYPTION = OFF;
        
        DECLARE @messageCount INT;
        SELECT @messageCount = 0;
        WHILE @messageCount < @messagesPerConversation
        BEGIN
            DECLARE @preparedPayload VARBINARY(max);
            SELECT @preparedPayload = dbo.BinaryMarhsalPayload(GETDATE(), @payload, USER_NAME());
            SEND ON CONVERSATION @h (@preparedPayload);
            SELECT @messageCount = @messageCount + 1, @batchCount = @batchCount + 1;
            
            IF @batchCount >= 100
            BEGIN
                COMMIT;
                SELECT @batchCount = 0;
                BEGIN TRANSACTION;
            END
        END
        SELECT @conversationCount = @conversationCount-1
    END
    COMMIT;
END
GO


-- this is where the testcase is executed.

    TRUNCATE TABLE dbo.PayloadData;

    DECLARE @payload VARBINARY(MAX);
    SELECT @payload = CAST(N'<Test/>' AS VARBINARY(MAX));
    EXEC LoadQueueReceivePerfBlog 100,100, @payload;
    GO
    DECLARE @msgCount FLOAT;
    DECLARE @startTime DATETIME;
    DECLARE @endTime DATETIME;
    SELECT @msgCount = COUNT(*) FROM [Target];
    SELECT @startTime = GETDATE();
    EXEC [RowsetBinaryDatagram];
    SELECT @endTime = GETDATE();
    SELECT @startTime as [Start],
        @endTime as [End],
        @msgCount as [Count],
        DATEDIFF(second, @startTime, @endTime) as [Duration],
        @msgCount/DATEDIFF(millisecond, @startTime, @endTime)*1000 as [Rate];

        