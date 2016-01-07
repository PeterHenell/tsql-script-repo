SET NOEXEC ON

    CREATE EVENT SESSION [Cardinality_SOUP] ON SERVER

    ADD EVENT sqlserver.inaccurate_cardinality_estimate
      ( 
        ACTION (sqlserver.plan_handle, 
                sqlserver.sql_text ) 
        WHERE ([actual_rows] > 1000)
       )

    ADD TARGET package0.ring_buffer
        (SET max_memory= 128000)
	    WITH (EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 10 SECONDS)
    GO

    -- START EVENT
    ALTER EVENT SESSION [Cardinality_SOUP] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [Cardinality_SOUP] ON SERVER DROP EVENT sqlserver.inaccurate_cardinality_estimate;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [Cardinality_SOUP] ON SERVER;

SET NOEXEC OFF;

    DECLARE @xml XML;
    SELECT @xml = CAST(target_data AS XML)
					FROM sys.dm_xe_session_targets st JOIN 
						sys.dm_xe_sessions s ON s.address = st.event_session_address
					WHERE st.target_name = 'ring_buffer' AND name = 'Cardinality_SOUP';
    

	SELECT
		n.query('event[1]/action[@name="sql_text"][1]').value('action[1]/value[1]', 'nvarchar(max)') AS  [data.sql_text],
        n.query('event[1]/action[@name="plan_handle"][1]').value('action[1]/value[1]', 'VARBINARY(64)') AS  [data.plan_handle],
        CAST(estimation_error_pcnt * row_counts.actual_rows AS DECIMAL) AS impact,
        estimation_error_pcnt,
        actual_rows,
        estimated_rows,
		--n.value('event[1]/@name[1]', 'varchar(500)') AS [event_name],
        rawXml
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
    CROSS APPLY(
        SELECT 
            n.query('event[1]/data[@name="estimated_rows"][1]').value('data[1]/value[1]', 'DECIMAL(19,2)') AS  [estimated_rows],
            n.query('event[1]/data[@name="actual_rows"][1]').value('data[1]/value[1]', 'DECIMAL(19,2)') AS  [actual_rows]
    ) row_counts
    CROSS APPLY (
        SELECT CAST((actual_rows - estimated_rows) / estimated_rows AS DECIMAL(30, 2)) * 100 AS estimation_error_pcnt
    ) diffs
    WHERE diffs.estimation_error_pcnt > 2.0
    ORDER BY impact DESC