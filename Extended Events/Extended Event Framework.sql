CREATE SCHEMA xe AUTHORIZATION dbo
GO

IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'StartTrace' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.StartTrace
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'StopTrace' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.StopTrace
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'DropTrace' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.DropTrace
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'ShowTraceDefinition' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.ShowTraceDefinition
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'ConsumeTraceData' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.ConsumeTraceData
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'MaterializeTrace' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.MaterializeTrace
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'ExecuteOrDebugPrint' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.ExecuteOrDebugPrint
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.routines WHERE ROUTINE_NAME = 'GetEventCount' AND ROUTINE_SCHEMA = 'xe')
	DROP PROC xe.GetEventCount
GO


IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.Tables WHERE Table_NAME = 'TraceData' AND Table_SCHEMA = 'xe')
	DROP TABLE xe.TraceData
GO
IF EXISTS( SELECT 1 FROM INFORMATION_SCHEMA.Tables WHERE Table_NAME = 'PredefinedTrace' AND Table_SCHEMA = 'xe')
	DROP TABLE xe.PredefinedTrace
GO

-- executes the sql text, unless the @debugLevel flag is set to 1 or 2;
-- Note! 
--		Will execute the command if @debugLevel is ANYTHING else than 1 or 2;
--
-- if the @debugLevel flag is set to 1 then it will only print the command
-- if the @debugLevel flag is set to 2 then it will print AND execute the command
-- @debugLevel default = 0
CREATE PROC xe.ExecuteOrDebugPrint
	@sql VARCHAR(MAX),
	@debugLevel int = 0
AS
BEGIN	
	IF @debugLevel IS NULL
		SET @debugLevel = 0;

	IF @debugLevel IN (1,2)
	BEGIN
		PRINT @sql;
		IF @debugLevel = 2 
			EXEC (@sql);
	END
	ELSE
		EXEC (@sql);

END

GO
CREATE TABLE xe.PredefinedTrace (
	PredefinedTraceId int IDENTITY(1, 1) CONSTRAINT [PK_PredefinedTrace] PRIMARY KEY CLUSTERED,
	TraceName sysname NOT NULL,
	Description VARCHAR(8000) NOT NULL,
	Created DATETIME2(2) NOT NULL CONSTRAINT [Def_PredefinedTrace_Created_Now] DEFAULT(SYSDATETIME()),
	IsRunning BIT NOT NULL CONSTRAINT [Def_PredefinedTrace_IsRunning_False] DEFAULT (0),
	StartedDate DATETIME2(7) NULL,
	TraceDefinition VARCHAR(max) NOT NULL,

	CONSTRAINT [UNQ_PredefinedTrace_Name] UNIQUE(TraceName)
);
GO

CREATE TABLE xe.TraceData (
	TraceDataId INT IDENTITY(1, 1) CONSTRAINT [PK_TraceData] PRIMARY KEY CLUSTERED,
	TraceName sysname CONSTRAINT [FK_TraceData_PredefinedTrace] FOREIGN KEY REFERENCES xe.PredefinedTrace(TraceName),
	Data XML NOT NULL,
	EventCount BIGINT NOT NULL,
	Created DATETIME2(7) CONSTRAINT [DEF_TraceData_Created_Now] DEFAULT(SYSDATETIME())
);
CREATE INDEX [IX_TraceData_PredefinedTraceId] ON xe.TraceData(TraceName) INCLUDE(Data);

CREATE PRIMARY XML INDEX [IX_TraceData_Data] ON xe.TraceData(Data);

CREATE XML INDEX [IX_TraceData_Data_property] ON xe.TraceData(Data)
USING XML INDEX [IX_TraceData_Data] FOR PROPERTY;


GO
CREATE PROC xe.ShowTraceDefinition
	@traceName sysname,
	@debugLevel INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @text VARCHAR(max),
			@description VARCHAR(MAX);
	SELECT @text = TraceDefinition ,
		   @description = Description
	FROM xe.PredefinedTrace WHERE TraceName = @traceName;

	
	PRINT '/*';
	PRINT @description
	PRINT '*/';
	PRINT @text
	
END
go

CREATE PROC xe.MaterializeTrace
	@traceName sysname,
	@debugLevel INT = 0
AS
BEGIN
	SET NOCOUNT ON;
	RAISERROR('TODO: making clustered index view or table containing all the data from the trace', 16, 1) WITH NOWAIT;
end

GO
CREATE PROC xe.StartTrace
	@traceName sysname,
	@dbName sysname,
	@debugLevel INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	PRINT 'Creating Event Session: [' + @traceName + ']';
	DECLARE @dbId int;
	DECLARE @sql varchar(MAX),
			@traceDefinition varchar(MAX);
	
	SELECT @dbId = DB_ID(@dbName);
	IF @dbId IS NULL 
	BEGIN
		RAISERROR('Supplied database name does not exist on this server', 16, 1) WITH NOWAIT;
		RETURN;
	END

	IF EXISTS(SELECT 1 FROM sys.server_event_sessions WHERE name = @traceName)
	BEGIN
		EXEC xe.DropTrace @traceName = @traceName, @debugLevel = @debugLevel
	END

	SELECT @traceDefinition = TraceDefinition FROM xe.PredefinedTrace WHERE TraceName = @traceName;
	IF @traceDefinition IS NULL
	BEGIN
		RAISERROR('Trace definition does not exist in PredefinedTrace', 16, 1) WITH NOWAIT;
		RETURN;
	END

	SET @traceDefinition = REPLACE(@traceDefinition, '<dbName,,>', @dbName);
	SET @traceDefinition = REPLACE(@traceDefinition, '<dbId,,>', @dbId);
	SET @traceDefinition = REPLACE(@traceDefinition, '<traceName,,>', @traceName);

	EXEC xe.ExecuteOrDebugPrint @traceDefinition, @debugLevel;

	PRINT 'Starting Event session: [' + @traceName + ']'; 
	SET @sql = 'ALTER EVENT SESSION [' + @traceName + '] ON SERVER STATE = START';
	EXEC xe.ExecuteOrDebugPrint @sql, @debugLevel;
END
GO

CREATE PROC xe.StopTrace
	@traceName sysname,
	@debugLevel INT = 0
AS
BEGIN
	SET NOCOUNT ON;

	PRINT 'Stopping Event Session: [' + @traceName + ']';

	IF NOT EXISTS(SELECT 1 	FROM sys.dm_xe_sessions ses	
							inner JOIN sys.dm_xe_session_events ev	ON ev.event_session_address = ses.address	
							WHERE name = @traceName)
	BEGIN
		--RAISERROR('Trace is not running', 16, 1) WITH nowait;
		PRINT 'Trace is not running';
		RETURN;
	END

	DECLARE @sql VARCHAR(MAX);
	SET @sql = 'ALTER EVENT SESSION [' + @traceName + '] ON SERVER DROP EVENT sqlserver.query_post_execution_showplan;';
	EXEC xe.ExecuteOrDebugPrint @sql, @debugLevel;
END
GO
	
CREATE PROC xe.DropTrace
	@traceName sysname,
	@debugLevel INT = 0
AS
	SET NOCOUNT ON;

	IF EXISTS(SELECT 1
		FROM sys.dm_xe_sessions AS s    
		WHERE s.name = @traceName)
	BEGIN
		PRINT 'Dropping event session: [' + @traceName + ']';
		DECLARE @sql VARCHAR(max) = 'DROP EVENT SESSION ['+ @traceName + '] ON SERVER;';
		EXEC xe.ExecuteOrDebugPrint @sql, @debugLevel;
	END	
GO

CREATE PROC xe.GetEventCount 
	@traceName sysname,
	@debugLevel INT = 0
AS
	SET NOCOUNT ON;

	DECLARE @xml XML;
	SELECT @xml = CAST(target_data AS XML) 
							FROM sys.dm_xe_session_targets st JOIN 
							  sys.dm_xe_sessions s ON s.address = st.event_session_address
						 WHERE name = @traceName AND st.target_name = 'ring_buffer';
	SELECT [EventCount] = @xml.value('RingBufferTarget[1]/@eventCount[1]', 'int' ) ;
GO



CREATE PROC xe.ConsumeTraceData
	@traceName sysname,
	@debugLevel INT = 0
AS
BEGIN
	SET NOCOUNT ON;
	PRINT 'Consuming Event Session: [' + @traceName + ']';

	IF NOT EXISTS(SELECT 1 FROM xe.PredefinedTrace WHERE TraceName = @traceName)
	BEGIN
		RAISERROR('Trace definition does not exist in PredefinedTrace', 16, 1) WITH NOWAIT;
		RETURN;
	END

	IF NOT EXISTS(SELECT 1 	FROM sys.dm_xe_sessions ses	
							inner JOIN sys.dm_xe_session_events ev	ON ev.event_session_address = ses.address	
							WHERE name = @traceName)
	BEGIN
		PRINT 'Trace is not running';
		RETURN;
	END

	DECLARE @xml XML,
			@eventCount BIGINT,
			@traceDataId BIGINT;

	SELECT @xml = CAST(target_data AS XML) 
							FROM sys.dm_xe_session_targets st JOIN 
							  sys.dm_xe_sessions s ON s.address = st.event_session_address
						 WHERE name = @traceName AND st.target_name = 'ring_buffer';
	SELECT @eventCount = COALESCE(@xml.value('RingBufferTarget[1]/@eventCount[1]', 'int'), 0);
	IF (@eventCount) < 1
	BEGIN
		PRINT 'No events to consume';
		RETURN;
	END

	PRINT 'Consuming ' + CAST(@eventCount AS VARCHAR(500)) + ' events';
	INSERT xe.TraceData
			(TraceName, Data, EventCount)
	VALUES (@traceName, @xml, @eventCount)

	SET @traceDataId = SCOPE_IDENTITY();

	DECLARE @sql VARCHAR(MAX);
	-- removing all the events that are in the buffers so that we do not consume them twice.
	SET @sql = 'ALTER EVENT SESSION [' + @traceName + '] ON SERVER STATE = STOP';
	EXEC xe.ExecuteOrDebugPrint @sql, @debugLevel;
	SET @sql = 'ALTER EVENT SESSION [' + @traceName + '] ON SERVER STATE = START';
	EXEC xe.ExecuteOrDebugPrint @sql, @debugLevel;

	SELECT [ConsumedEvents] = @eventCount,
		   [TraceDataId] = @traceDataId
END
go


INSERT xe.PredefinedTrace
        ( TraceName , Description, TraceDefinition )
SELECT
'ActualExecutionPlan',
'Session to collect execution plan for long running queries (duration > 5 sec)',
'    CREATE EVENT SESSION [<traceName,,>] ON SERVER 
	ADD EVENT sqlserver.query_post_execution_showplan (
	ACTION ( 
				sqlserver.session_id,
				package0.collect_system_time,
				package0.event_sequence,
				sqlserver.sql_text
			) 
		WHERE ( 
				sqlserver.database_id=<dbId,,>
				AND sqlserver.username LIKE ''<dbName,,>[_]r_''
				AND duration > 5000
				)
	)
	ADD TARGET package0.ring_buffer(SET max_memory= 128000)
	WITH (EVENT_RETENTION_MODE = NO_EVENT_LOSS, MAX_DISPATCH_LATENCY = 1 SECONDS);'


INSERT xe.PredefinedTrace
        ( TraceName , Description, TraceDefinition )
SELECT
'LockTrace',
'Session to collect all locks aqcuired and released',
'    CREATE EVENT SESSION [<traceName,,>] ON SERVER 
	ADD EVENT sqlserver.query_post_execution_showplan (
	ACTION ( 
				sqlserver.session_id,
				package0.collect_system_time,
				package0.event_sequence,
				sqlserver.sql_text
			) 
		WHERE ( 
				sqlserver.database_id=<dbId,,>
				AND sqlserver.username LIKE ''<dbName,,>[_]r_''
				AND duration > 5000
				)
	)
	ADD TARGET package0.ring_buffer(SET max_memory= 128000)
	WITH (EVENT_RETENTION_MODE = NO_EVENT_LOSS, MAX_DISPATCH_LATENCY = 1 SECONDS);'

GO


--SELECT * FROM xe.PredefinedTrace

EXEC xe.ShowTraceDefinition @traceName = 'ActualExecutionPlan';
EXEC xe.StartTrace @traceName = 'ActualExecutionPlan', @dbName = 'devdba_gp_cl01';
EXEC xe.StartTrace @traceName = 'ActualExecutionPlan', @dbName = 'devdba_gp_cl01';

EXEC xe.GetEventCount @traceName = 'ActualExecutionPlan'

EXEC xe.ConsumeTraceData @traceName = 'ActualExecutionPlan';

EXEC xe.StopTrace @traceName = 'ActualExecutionPlan';
EXEC xe.StopTrace @traceName = 'ActualExecutionPlan';

EXEC xe.DropTrace @traceName = 'ActualExecutionPlan';
EXEC xe.DropTrace @traceName = 'ActualExecutionPlan';

RETURN;
--	SELECT * FROM xe.TraceData

				

