SET NOEXEC ON

    CREATE EVENT SESSION [Multistatement_SP_Collector] ON SERVER
     
        ADD EVENT sqlserver.module_end (
            ACTION (
                    sqlserver.tsql_stack, 
                    sqlserver.sql_text,
                    sqlserver.client_hostname,
                    sqlserver.client_app_name,
                    sqlserver.plan_handle,
                    package0.callstack,
			        sqlserver.query_hash,
			        sqlserver.session_id,
                    sqlserver.request_id,
                    package0.collect_system_time,
				    package0.event_sequence )
            --   WHERE duration > 1000 AND session_id = 65
            ),
        ADD EVENT sqlserver.sp_statement_completed (
            ACTION (
                    sqlserver.client_hostname,
                    sqlserver.client_app_name,
                    sqlserver.plan_handle,
                    sqlserver.sql_text,
                    sqlserver.tsql_stack,
                    package0.callstack,
			        sqlserver.query_hash,
			        sqlserver.session_id,
                    sqlserver.request_id,
                    package0.collect_system_time,
				    package0.event_sequence )
            --   WHERE duration > 1000 AND session_id = 65
            )

	   
    ADD TARGET package0.ring_buffer
        (SET MAX_MEMORY = 128000)
	    WITH (EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 10 SECONDS,
              MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
    GO

    -- START EVENT
    ALTER EVENT SESSION [Multistatement_SP_Collector] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [Multistatement_SP_Collector] ON SERVER DROP EVENT sqlserver.module_end;
    ALTER EVENT SESSION [Multistatement_SP_Collector] ON SERVER DROP EVENT sqlserver.sp_statement_completed;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [Multistatement_SP_Collector] ON SERVER;
    -- Running Traces
    SELECT * FROM sys.dm_xe_sessions

SET NOEXEC OFF;

         SELECT event_name
			,event_data.value('(event/@timestamp)[1]', 'datetime') AS [timestamp]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="callstack"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [callstack]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [client_app_name]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [client_hostname]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="collect_system_time"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [collect_system_time]
		    ,CASE WHEN event_name in ('sp_statement_completed') THEN event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') ELSE NULL END AS [cpu_time]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') ELSE NULL END AS [duration]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="event_sequence"]/value)[1]', 'bigint') ELSE NULL END AS [event_sequence]
		    ,CASE WHEN event_name in ('sp_statement_completed') THEN event_data.value('(event/data[@name="last_row_count"]/value)[1]', 'bigint') ELSE NULL END AS [last_row_count]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="line_number"]/value)[1]', 'int') ELSE NULL END AS [line_number]
		    ,CASE WHEN event_name in ('sp_statement_completed') THEN event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') ELSE NULL END AS [logical_reads]
		    ,CASE WHEN event_name in ('sp_statement_completed') THEN event_data.value('(event/data[@name="nest_level"]/value)[1]', 'int') ELSE NULL END AS [nest_level]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="object_id"]/value)[1]', 'int') ELSE NULL END AS [object_id]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="object_name"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [object_name]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="object_type"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [object_type]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="offset"]/value)[1]', 'int') ELSE NULL END AS [offset]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="offset_end"]/value)[1]', 'int') ELSE NULL END AS [offset_end]
		    ,CASE WHEN event_name in ('sp_statement_completed') THEN event_data.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint') ELSE NULL END AS [physical_reads]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="plan_handle"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [plan_handle]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="query_hash"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [query_hash]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="request_id"]/value)[1]', 'int') ELSE NULL END AS [request_id]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint') ELSE NULL END AS [row_count]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') ELSE NULL END AS [session_id]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="source_database_id"]/value)[1]', 'int') ELSE NULL END AS [source_database_id]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [sql_text]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [statement]
		    ,CASE WHEN event_name in ('module_end','sp_statement_completed') THEN event_data.value('(event/action[@name="tsql_stack"]/value)[1]', 'nvarchar(4000)') ELSE NULL END AS [tsql_stack]
		    ,CASE WHEN event_name in ('sp_statement_completed') THEN event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') ELSE NULL END AS [writes]
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
					WHERE s.name = 'Multistatement_SP_Collector'
						AND t.target_name = 'ring_buffer'
				) AS sub
				CROSS APPLY target_data.nodes('RingBufferTarget[1]/event') AS q(td)
			) a
		