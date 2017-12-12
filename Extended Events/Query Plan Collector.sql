SET NOEXEC ON

    CREATE EVENT SESSION [Queryplan_Collector] ON SERVER

       ADD EVENT sqlserver.query_post_execution_showplan(
           ACTION ( sqlserver.database_name,
                    sqlserver.client_hostname,
                    sqlserver.client_app_name,
                    sqlserver.plan_handle,
                    sqlserver.sql_text,
                    sqlserver.tsql_stack,
                    package0.callstack,
			        sqlserver.query_hash,
			        sqlserver.session_id,
                    sqlserver.request_id ) 
        WHERE username = 'SPOTIFY\sqlagentsvcdev' AND duration > 1000 --AND session_id = 65
    )

	   
    ADD TARGET package0.ring_buffer
        (SET MAX_MEMORY = 128000, MAX_EVENTS_LIMIT = 0)
	    WITH (EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 10 SECONDS,
              MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
    GO

    -- START EVENT
    ALTER EVENT SESSION [Queryplan_Collector] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [Queryplan_Collector] ON SERVER DROP EVENT sqlserver.query_post_execution_showplan;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [Queryplan_Collector] ON SERVER;
    -- Running Traces
    SELECT * FROM sys.dm_xe_sessions

SET NOEXEC OFF;

    DECLARE @xml XML;
    SELECT @xml = CAST(target_data AS XML)
	FROM sys.dm_xe_session_targets st 
    JOIN sys.dm_xe_sessions s 
         ON s.address = st.event_session_address
	WHERE st.target_name = 'ring_buffer' AND name = 'Queryplan_Collector';
    
    WITH XMLNAMESPACES('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS s) 
	SELECT
		n.query('event[1]/action[@name="sql_text"][1]').value('action[1]/value[1]', 'NVARCHAR(MAX)') AS  [sql_text],
        n.query('event[1]/data[@name="duration"][1]').value('data[1]/value[1]', 'BIGINT') / 1000 AS  duration_ms,
        n.query('event[1]/data[@name="estimated_rows"][1]').value('data[1]/value[1]', 'BIGINT') AS  est_rows,
        n.query('event[1]/data[@name="estimated_cost"][1]').value('data[1]/value[1]', 'BIGINT') AS  est_cost,
        n.query('event[1]/data[@name="object_name"][1]').value('data[1]/value[1]', 'VARCHAR(200)') AS  object_name,
        n.query('event[1]/data[@name="object_type"][1]').value('data[1]/value[1]', 'VARCHAR(200)') AS  object_type,
        n.query('event[1]/data[@name="nest_level"][1]').value('data[1]/value[1]', 'BIGINT') AS  nest_level,
        n.query('event[1]/data[@name="cpu_time"][1]').value('data[1]/value[1]', 'BIGINT') AS  cpu_time,
        xmlplan.query('.') AS plan_xml
        --,rawXml
	FROM 
	(
		SELECT @xml AS rawXml
	) trace
	CROSS APPLY 
		rawXml.nodes('RingBufferTarget[1]/event') as xmlNodes(nds)
	CROSS APPLY
	(
		SELECT xmlNodes.nds.query('.')  AS n
	) queries
    CROSS APPLY n.nodes('(event/data[@name="showplan_xml"]/value)[last()]/*') AS showplan(xmlplan)

