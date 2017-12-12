SET NOEXEC ON

    CREATE EVENT SESSION [LocksAquired] ON SERVER
    ADD EVENT sqlserver.lock_acquired
    (
      SET collect_resource_description=(1)
      
      WHERE 
              database_id > 4         -- non system database
          AND sqlserver.is_system = 0 -- must be a user process
    )


     ADD TARGET package0.histogram(SET filtering_event_name = N'sqlserver.lock_acquired', source = N'resource_type', source_type = (0), slots = 20)
        WITH (MAX_MEMORY = 4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
        MAX_DISPATCH_LATENCY = 5 SECONDS, MAX_EVENT_SIZE = 0 KB, MEMORY_PARTITION_MODE = NONE,
        TRACK_CAUSALITY = OFF, STARTUP_STATE = OFF);

    -- START EVENT
    ALTER EVENT SESSION [LocksAquired] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [LocksAquired] ON SERVER DROP EVENT sqlserver.lock_acquired;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [LocksAquired] ON SERVER;
    -- Running Traces
    SELECT * FROM sys.dm_xe_sessions

SET NOEXEC OFF;

   -- query for histogram target
   SELECT 
        [Resource Type] = 
            CASE xed.slot_data.value('(value)[1]', 'bigint') 
                WHEN 1	THEN 'NULL_RESOURCE    '
                WHEN 2	THEN 'DATABASE         '
                WHEN 3	THEN 'FILE             '
                WHEN 4	THEN 'UNUSED1          '
                WHEN 5	THEN 'OBJECT           '
                WHEN 6	THEN 'PAGE             '
                WHEN 7	THEN 'KEY              '
                WHEN 8	THEN 'EXTENT           '
                WHEN 9	THEN 'RID              '
                WHEN 10	THEN 'APPLICATION      '
                WHEN 11	THEN 'METADATA         '
                WHEN 12	THEN 'HOBT             '
                WHEN 13	THEN 'ALLOCATION_UNIT  '
                WHEN 14	THEN 'OIB              '
                WHEN 15	THEN 'ROWGROUP         '
                WHEN 16	THEN 'LAST_RESOURCE    '
            END,
        [Lock Count] = xed.slot_data.value('(@count)[1]', 'numeric(38,0)')
    FROM (
        SELECT 
            CAST(xet.target_data AS xml)  as target_data
        FROM sys.dm_xe_session_targets AS xet  
        JOIN sys.dm_xe_sessions AS xe  
           ON (xe.address = xet.event_session_address)  
        WHERE xe.name = 'LocksAquired' 
            and target_name='histogram'
        ) as t
    CROSS APPLY t.target_data.nodes('//HistogramTarget/Slot') AS xed (slot_data);

    /*
    Trace Definition Inspired from https://www.sqlskills.com/blogs/jonathan/tracking-sql-server-database-usage/
    Meta-data queries below stolen from the same.

        SELECT
            name,
            column_id,
            type_name,*
        FROM sys.dm_xe_object_columns
        WHERE object_name = N'lock_acquired' AND
            column_type = N'data';
 
-- Look up the values for the Lock Resource Type and the Lock Owner Type
    SELECT
        name,
        map_key,
        map_value
    FROM sys.dm_xe_map_values
    WHERE name IN (N'lock_resource_type', N'lock_owner_type')
    ORDER BY name,map_key;


*/