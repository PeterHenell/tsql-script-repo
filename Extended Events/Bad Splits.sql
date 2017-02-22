SET NOEXEC ON
    CREATE EVENT SESSION [BadSplits] ON SERVER

        ADD EVENT sqlserver.transaction_log(
            WHERE Operation = 11  -- LOP_DELETE_SPLIT
                  --AND session_id = 60 -- alter for each try
        )
        ADD TARGET package0.ring_buffer (SET MAX_MEMORY = 128000)
	    WITH (EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 10 SECONDS,
                  MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
    GO
 
    -- START EVENT
    ALTER EVENT SESSION [BadSplits] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [BadSplits] ON SERVER DROP EVENT qlserver.transaction_log;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [BadSplits] ON SERVER;
    -- Running Traces
    SELECT * FROM sys.dm_xe_sessions

SET NOEXEC OFF;


    DECLARE @xml XML;
    SELECT @xml = CAST(target_data AS XML)
	FROM sys.dm_xe_session_targets st 
    JOIN sys.dm_xe_sessions s 
         ON s.address = st.event_session_address
	WHERE st.target_name = 'ring_buffer' AND name = 'BadSplits';

    -- First query: Get high level count per database
    WITH qry AS
            (
                 SELECT
                    theNodes.event_data.value('(data[@name="database_id"]/value)[1]','int') AS database_id
                 FROM
                 (SELECT @xml event_data) theData
                 CROSS APPLY theData.event_data.nodes('//event') theNodes(event_data) 
             )
    SELECT DB_NAME(database_id),COUNT(*) AS total 
    FROM qry
    GROUP BY DB_NAME(database_id)
    ORDER BY total DESC;

    -- Second query: Get split count per object
    WITH qry AS
             (
                SELECT
                    theNodes.event_data.value('(data[@name="database_id"]/value)[1]','int') AS database_id,
                    theNodes.event_data.value('(data[@name="alloc_unit_id"]/value)[1]','varchar(30)') AS alloc_unit_id,
                    theNodes.event_data.value('(data[@name="context"]/text)[1]','varchar(30)') AS context
                    --theNodes.event_data.value('(data[@name="operation"]/text)[1]','varchar(60)') AS operation
                FROM
                (SELECT @xml event_data) theData
                CROSS APPLY theData.event_data.nodes('//event') theNodes(event_data) 
            )
    SELECT name,context, COUNT(*) AS totalSplits
    FROM qry
    LEFT JOIN sys.allocation_units au
        ON qry.alloc_unit_id=au.allocation_unit_id
    LEFT JOIN sys.partitions p
        ON au.container_id=p.hobt_id 
        AND (au.type=1 OR au.type=3)
    LEFT JOIN sys.objects ob
        ON p.object_id=ob.object_id
    WHERE 
        database_id = DB_ID() -- We must be located in the same database as the split occured. 
                              -- This is because the sys.allocation_units and sys.partition dmvs are database specific.
    GROUP BY name,context
    ORDER BY name