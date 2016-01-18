SET NOEXEC ON

    CREATE EVENT SESSION MonitorWaits ON SERVER
        ADD EVENT sqlos.wait_info
            (
             ACTION ( sqlserver.database_name,
                      sqlserver.client_hostname,
                      sqlserver.client_app_name,
                      sqlserver.plan_handle,
                      sqlserver.sql_text,
	            sqlserver.session_id,
                      sqlserver.request_id )
             WHERE sqlserver.session_id = 54 /* session_id of connection to monitor */)

        --ADD TARGET package0.ring_buffer
        --   (SET MAX_MEMORY = 128000)
            
        ADD TARGET package0.histogram
               (SET slots = 128, filtering_event_name = 'sqlos.wait_info', source_type = 0, source = 'wait_type')
	        
        WITH (EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 1 SECONDS,
              MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
            
    ALTER EVENT SESSION MonitorWaits ON SERVER STATE = START;

    ALTER EVENT SESSION MonitorWaits ON SERVER DROP EVENT sqlos.wait_info; -- use this to stop the collection while also keeping the data in the buffer.
    ALTER EVENT SESSION MonitorWaits ON SERVER ADD EVENT sqlos.wait_info (WHERE sqlserver.session_id = 54);

    -- Stopping the session will clear the ring_buffer.
    ALTER EVENT SESSION MonitorWaits ON SERVER STATE = STOP;
    DROP EVENT SESSION MonitorWaits ON SERVER;
    GO


-- Use these to filter out specific wait types
SELECT xmv.map_key, xmv.map_value
FROM sys.dm_xe_map_values xmv
JOIN sys.dm_xe_packages xp
    ON xmv.object_package_guid = xp.guid
WHERE xmv.name = 'wait_types'
    AND xp.name = 'sqlos';
    --AND xmv.map_key = '404'
GO


SET NOEXEC OFF;

-- Show collected waits for the RING BUFFER
WITH wait_xml(wait_xml) AS (
    SELECT CAST(xet.target_data AS xml)
    FROM sys.dm_xe_session_targets AS xet
    JOIN sys.dm_xe_sessions AS xe ON (xe.address = xet.event_session_address)
    WHERE xe.name = 'MonitorWaits' AND xet.target_name = 'ring_buffer'
)
, wait_info AS (
    SELECT 
        xed.event_data.value('(@timestamp)[1]', 'datetime2') AS [timestamp],
        xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(25)') AS wait_type, 
        xed.event_data.value('(data[@name="duration"]/value)[1]', 'int') AS wait_type_duration_ms, 
        xed.event_data.value('(data[@name="signal_duration"]/value)[1]', 'int') AS wait_type_signal_duration_ms 
    FROM wait_xml
      CROSS APPLY wait_xml.nodes('/RingBufferTarget/event') AS xed (event_data)
)
SELECT xei.wait_type, 
    COUNT(xei.wait_type) AS [Waited #], 
    SUM(xei.wait_type_duration_ms) AS [Total Wait Time (ms)], 
    SUM(xei.wait_type_signal_duration_ms) AS [Total Signal Time (ms)],
    SUM(xei.wait_type_duration_ms) - SUM (xei.wait_type_signal_duration_ms) AS [Total Resource Wait Time (ms)]
FROM wait_info xei
GROUP BY xei.wait_type
ORDER BY SUM(xei.wait_type_duration_ms) DESC;


-- Show collected waits for HISTOGRAM, counting the number of time an wait_type occurs.
WITH wait_xml(wait_xml) AS (
    SELECT CAST(xet.target_data AS xml)
    FROM sys.dm_xe_session_targets AS xet
    JOIN sys.dm_xe_sessions AS xe ON (xe.address = xet.event_session_address)
    WHERE xe.name = 'MonitorWaits' AND xet.target_name = 'histogram'
)
    SELECT  event_data.value('./@count', 'int') AS [Count] ,
            wait_type.id AS [Wait Type ID],
            [Wait Type]
    FROM wait_xml
      CROSS APPLY wait_xml.nodes('/HistogramTarget/Slot') AS xed (event_data)
      CROSS APPLY (SELECT event_data.query('./value').value('.', 'varchar(20)')) AS wait_type(id)
      CROSS APPLY (
        SELECT xmv.map_value AS [Wait Type]
        FROM sys.dm_xe_map_values xmv
        JOIN sys.dm_xe_packages xp
            ON xmv.object_package_guid = xp.guid
        WHERE xmv.name = 'wait_types'
            AND xp.name = 'sqlos'
            AND xmv.map_key = wait_type.id) wait_types
