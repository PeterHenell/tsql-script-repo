SET NOEXEC ON

    CREATE EVENT SESSION [LocksAquired] ON SERVER
    ADD EVENT sqlserver.lock_acquired
    (
        SET collect_resource_description=(1)
        ACTION(
            package0.callstack,
            sqlserver.session_id,
            sqlserver.sql_text,
            sqlserver.tsql_stack,
            package0.event_sequence
            )
        WHERE session_id = 57
     )
    ADD TARGET package0.ring_buffer
        (SET MAX_MEMORY = 128000, MAX_EVENTS_LIMIT = 0)
	    WITH (EVENT_RETENTION_MODE = NO_EVENT_LOSS, MAX_DISPATCH_LATENCY = 10 SECONDS,
              MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);

    -- START EVENT
    ALTER EVENT SESSION [LocksAquired] ON SERVER	STATE = START;
    -- STOP EVENT, keep data in ring buffer
    ALTER EVENT SESSION [LocksAquired] ON SERVER DROP EVENT sqlserver.lock_acquired;
    -- REMOVE EVENT SESSION
    DROP EVENT SESSION [LocksAquired] ON SERVER;
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
                dxs.name = 'LocksAquired'
                AND dxst.target_name = N'ring_buffer'
            )
        );
        WITH a AS ( SELECT  t.c.value('@name', 'nvarchar(50)') AS event_name ,
                            t.c.value('(action[@name="event_sequence"]/value)[1]','varchar(200)') AS event_sequence,
                            t.c.value('@timestamp', 'datetime2') AS event_time ,
                            st.statement_text,
                            t.c.value('(data[@name="associated_object_id"]/value)[1]','numeric(20)') AS associated_object_id ,
                            t.c.value('(data[@name="resource_0"]/value)[1]','bigint') AS resource_0 ,
                            t.c.value('(data[@name="resource_1"]/value)[1]','bigint') AS resource_1 ,
                            t.c.value('(data[@name="resource_2"]/value)[1]','bigint') AS resource_3 ,
                            t.c.value('(data[@name="mode"]/text)[1]','varchar(50)') AS mode ,
                            t.c.value('(data[@name="resource_type"]/text)[1]','varchar(50)') AS resource_type ,
                            t.c.value('(data[@name="database_id"]/value)[1]','int') AS database_id ,
                            t.c.value('(data[@name="object_id"]/value)[1]','int') AS object_id ,
                            t.c.value('(data[@name="owner_type"]/text)[1]','varchar(50)') AS owner_type ,
                            t.c.value('(action[@name="attach_activity_id"]/value)[1]','varchar(200)') AS attach_activity_id

                   FROM     ( SELECT    @xml AS event_xml) target_read_file
                            CROSS APPLY event_xml.nodes('//event') AS t ( c )
                            CROSS APPLY (SELECT CAST(t.c.query('(action[@name="tsql_stack"]/value)[1][last()]/*') AS xml)) AS sql_stack(value)
                            CROSS APPLY (SELECT 
                                            frame_xml.value('(./@level)[1]', 'int') as [frame_level],
                                            frame_xml.value('(./@handle[1])', 'varchar(MAX)') as [sql_handle],
                                            frame_xml.value('(./@offsetStart[1])', 'int') as [offset_start],
                                            frame_xml.value('(./@offsetEnd[1])', 'int') as [offset_end]
                                        FROM sql_stack.value.nodes('//frame') n(frame_xml)
                                        ) sql_frames
                            OUTER APPLY 
                                (SELECT 
                                    SUBSTRING(st.text, ([sql_frames].[offset_start]/2)+1, 
                                        ((CASE [sql_frames].[offset_end]
                                          WHEN -1 THEN DATALENGTH(st.text)
                                         ELSE [sql_frames].[offset_end]
                                         END - [sql_frames].[offset_start])/2) + 1) AS statement_text
                                    FROM sys.dm_exec_sql_text(CONVERT(VARBINARY(max), sql_frames.sql_handle,1)) AS st
                                    ) AS st
                   WHERE    t.c.value('@name', 'nvarchar(50)') = 'lock_acquired'
                            AND t.c.value('(data[@name="associated_object_id"]/value)[1]','numeric(20)') > 0
                            AND t.c.value('(data[@name="database_id"]/value)[1]','int') <> 2
                 )
        SELECT  a.*,
                OBJECT_NAME(ISNULL(p.object_id, a.object_id), a.database_id) object_name
        FROM    a
                LEFT JOIN sys.partitions p ON a.associated_object_id = p.hobt_id
