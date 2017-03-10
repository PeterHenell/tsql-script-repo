SET NOEXEC ON

    CREATE EVENT SESSION [LockEscalations] ON SERVER

       ADD EVENT sqlserver.lock_escalation(
           ACTION ( sqlserver.database_name,
                    sqlserver.plan_handle,
                    sqlserver.sql_text,
			        sqlserver.session_id,
                    sqlserver.request_id,
                    sqlserver.tsql_stack ) 
     --   WHERE duration > 1000 AND session_id = 65
    )

	   
    ADD TARGET package0.ring_buffer
        (SET MAX_MEMORY = 128000)
	    WITH (EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 10 SECONDS,
              MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
    GO

    -- START EVENT
    ALTER EVENT SESSION [LockEscalations] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [LockEscalations] ON SERVER DROP EVENT sqlserver.lock_escalation;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [LockEscalations] ON SERVER;
    -- Running Traces
    SELECT * FROM sys.dm_xe_sessions

SET NOEXEC OFF;

    SELECT event_name
		 ,event_data.value('(event/@timestamp)[1]', 'datetime') AS [timestamp]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="database_id"]/value)[1]', 'int') ELSE NULL END AS [database_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="database_name"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [database_name]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="escalated_lock_count"]/value)[1]', 'int') ELSE NULL END AS [escalated_lock_count]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="escalation_cause"]/text)[1]', 'nvarchar(20)') ELSE NULL END AS [escalation_cause]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="hobt_id"]/value)[1]', 'bigint') ELSE NULL END AS [hobt_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="hobt_lock_count"]/value)[1]', 'int') ELSE NULL END AS [hobt_lock_count]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="lockspace_nest_id"]/value)[1]', 'int') ELSE NULL END AS [lockspace_nest_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="lockspace_sub_id"]/value)[1]', 'int') ELSE NULL END AS [lockspace_sub_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="lockspace_workspace_id"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [lockspace_workspace_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="mode"]/text)[1]', 'nvarchar(10)') ELSE NULL END AS [mode]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="object_id"]/value)[1]', 'int') ELSE NULL END AS [object_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="owner_type"]/text)[1]', 'nvarchar(40)') ELSE NULL END AS [owner_type]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/action[@name="plan_handle"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [plan_handle]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/action[@name="request_id"]/value)[1]', 'int') ELSE NULL END AS [request_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="resource_0"]/value)[1]', 'int') ELSE NULL END AS [resource_0]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="resource_1"]/value)[1]', 'int') ELSE NULL END AS [resource_1]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="resource_2"]/value)[1]', 'int') ELSE NULL END AS [resource_2]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="resource_type"]/text)[1]', 'nvarchar(30)') ELSE NULL END AS [resource_type]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') ELSE NULL END AS [session_id]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [sql_text]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [statement]
		,CASE WHEN event_name in ('lock_escalation') THEN event_data.value('(event/data[@name="transaction_id"]/value)[1]', 'bigint') ELSE NULL END AS [transaction_id]
		FROM (
				SELECT td.query('.') AS event_data
				,td.value('@name', 'sysname') as event_name
				,td.value('@timestamp', 'datetime') as timestamp
				FROM 
				(
					SELECT CAST(target_data AS XML) as target_data
					FROM sys.dm_xe_sessions AS s    
					JOIN sys.dm_xe_session_targets AS t
						ON s.address = t.event_session_address
					WHERE s.name = 'LockEscalations'
						AND t.target_name = 'ring_buffer'
				) AS sub
				CROSS APPLY target_data.nodes('RingBufferTarget[1]/event') AS q(td)
			) a

