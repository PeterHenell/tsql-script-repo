SET NOEXEC ON

    CREATE EVENT SESSION [LockEscalations] ON SERVER

       ADD EVENT sqlserver.lock_escalation(
           ACTION ( sqlserver.database_name,
                    sqlserver.plan_handle,
                    sqlserver.sql_text,
			        sqlserver.session_id,
                    sqlserver.request_id,
                    sqlserver.tsql_stack,
                    package0.callstack,
			        sqlserver.query_hash ) 
     --   WHERE duration > 1000 AND session_id = 65
    )

	   
    ADD TARGET package0.ring_buffer
        (SET MAX_MEMORY = 128000)
	    WITH (event_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 10 SECONDS,
              MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);

    -- START EVENT
    ALTER EVENT SESSION [LockEscalations] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [LockEscalations] ON SERVER DROP EVENT sqlserver.lock_escalation;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [LockEscalations] ON SERVER;
    -- Running Traces
    SELECT * FROM sys.dm_xe_sessions

SET NOEXEC OFF;


        DECLARE @xml xml =
        CONVERT
        (
            xml,
            (
            SELECT TOP (1)
                dxst.target_data
            FROM sys.dm_xe_sessions AS dxs 
            JOIN sys.dm_xe_session_targets AS dxst ON
                dxst.event_session_address = dxs.[address]
            WHERE 
                dxs.name = 'LockEscalations'
                AND dxst.target_name = N'ring_buffer'
            )
        );
        
        SELECT  event_name
                ,db.name
		        ,event_data.value('(event[1]/@timestamp)[1]', 'datetime') AS [timestamp],
                fields.*
                ,so.name
                
		FROM (
				SELECT td.query('.') AS event_data
				,td.value('@name', 'sysname') as event_name
				,td.value('@timestamp', 'datetime') as timestamp
				FROM @xml.nodes('RingBufferTarget[1]/event') AS q(td)
			) a
            CROSS APPLY (
            SELECT
		         [callstack] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/action[@name="callstack"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ,[database_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="database_id"]/value)[1]', 'bigint') ELSE NULL END 
                ,[database_name] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="database_name"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ,[escalated_lock_count] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="escalated_lock_count"]/value)[1]', 'bigint') ELSE NULL END 
                ,[escalation_cause] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="escalation_cause"]/text)[1]', 'nvarchar(20)') ELSE NULL END 
                ,[hobt_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="hobt_id"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ,[hobt_lock_count] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="hobt_lock_count"]/value)[1]', 'bigint') ELSE NULL END 
                ,[lockspace_nest_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="lockspace_nest_id"]/value)[1]', 'bigint') ELSE NULL END 
                ,[lockspace_sub_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="lockspace_sub_id"]/value)[1]', 'bigint') ELSE NULL END 
                ,[lockspace_workspace_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="lockspace_workspace_id"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ,[mode] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="mode"]/text)[1]', 'nvarchar(10)') ELSE NULL END 
                ,[object_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="object_id"]/value)[1]', 'int') ELSE NULL END 
                ,[owner_type] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="owner_type"]/text)[1]', 'nvarchar(40)') ELSE NULL END 
                ,[plan_handle] = CAST(event_data.value('(event[1]/action[@name="plan_handle"]/value)[1]', 'varchar(max)') AS XML)
                ,[query_hash] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/action[@name="query_hash"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ,[request_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/action[@name="request_id"]/value)[1]', 'bigint') ELSE NULL END 
                ,[resource_0] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="resource_0"]/value)[1]', 'bigint') ELSE NULL END 
                ,[resource_1] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="resource_1"]/value)[1]', 'bigint') ELSE NULL END 
                ,[resource_2] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="resource_2"]/value)[1]', 'bigint') ELSE NULL END 
                ,[resource_type] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="resource_type"]/text)[1]', 'nvarchar(30)') ELSE NULL END 
                ,[session_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/action[@name="session_id"]/value)[1]', 'int') ELSE NULL END 
                ,[sql_text] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/action[@name="sql_text"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ,[statement] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="statement"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ,[transaction_id] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/data[@name="transaction_id"]/value)[1]', 'bigint') ELSE NULL END 
                ,[tsql_stack] = CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event[1]/action[@name="tsql_stack"]/value)[1]', 'nvarchar(4000)') ELSE NULL END 
                ) fields
		    CROSS APPLY (SELECT DB_NAME(fields.database_id)) db(name)

INNER JOIN sys.objects so ON so.object_id = fields.object_id
--CROSS APPLY (SELECT plan_handle.value('xs:hexBinary(substring((plan_handle)[1], 3))', 'varbinary(max)')) as qp(v)
--CROSS APPLY sys.dm_exec_query_plan(plan_handle.value('xs:hexBinary(substring((plan/@handle)[1], 3))', 'varbinary(max)')) as qp
