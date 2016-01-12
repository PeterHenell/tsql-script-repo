-- https://blogs.technet.microsoft.com/sqlcontent/2012/12/20/how-it-works-cmemthread-and-debugging-them/
--First get the map_key for CMEMTHREAD wait type from the name-value pairs for all wait types stored in sys.dm_xe_map_values
--NOTE :- These map values are different b/w SQL Server 2008 R2 and 2012
select m.* from sys.dm_xe_map_values m
      join sys.dm_xe_packages p on m.object_package_guid = p.guid
where p.name = 'sqlos' and m.name = 'wait_types'
      and m.map_value = 'CMEMTHREAD'
 
/*
name                                                         object_package_guid                  map_key     map_value
———————————————————— ———————————— ———-- —————
wait_types                                                   BD97CC63-3F38-4922-AA93-607BD12E78B2 186         CMEMTHREAD
*/
--Create an Extended Events session to capture callstacks for CMEMTHREAD waits ( map_key=186 on SQL Server 2008 R2) 
--Create an Extended Events session to capture callstacks for CMEMTHREAD waits ( map_key=186 on SQL Server 2008 R2)

 
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='XeWaitsOnCMemThread')
      DROP EVENT SESSION [XeWaitsOnCMemThread] ON SERVER
CREATE EVENT SESSION [XeWaitsOnCMemThread] ON SERVER
ADD EVENT sqlos.wait_info(
    ACTION(package0.callstack,sqlserver.session_id,sqlserver.sql_text)
WHERE (
              [wait_type]=(186)) --map_key for CMEMTHREAD on SQL Server 2008 R2)
              AND [opcode] = (1)
              AND [duration]> 5000 -- waits exceed 5 seconds
              )
ADD TARGET package0.asynchronous_bucketizer
(SET filtering_event_name=N'sqlos.wait_info',
     source_type=1,
     source=N'package0.callstack')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
MAX_DISPATCH_LATENCY=5 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO
 
--Create second Xevent session to generate a mini dump of all threads for the first two wait events catpured for CMEMTHREAD
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='XeDumpOnCMemThread')
      DROP EVENT SESSION [XeDumpOnCMemThread] ON SERVER
CREATE EVENT SESSION [XeDumpOnCMemThread] ON SERVER
ADD EVENT sqlos.wait_info(
    ACTION(sqlserver.session_id,sqlserver.sql_text,sqlserver.create_dump_all_threads)
WHERE (
              [wait_type]=(186)) --map_key for CMEMTHREAD on SQL Server 2008 R2)
              AND [opcode] = (1)
              AND [duration]> 5000 -- waits exceed 5 seconds
              AND package0.counter <=2 --number of times to generate a dump
              )
add target package0.ring_buffer
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
MAX_DISPATCH_LATENCY=5 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO
 
--Start the sessions
ALTER EVENT SESSION [XeWaitsOnCMemThread] ON SERVER STATE=START
GO 
ALTER EVENT SESSION [XeDumpOnCMemThread] ON SERVER STATE=START
GO
 
--When you collect data using the histogram target, you can acquire the un-symbolized call stack using the following query.
 
SELECT
    n.value('(@count)[1]', 'int') AS EventCount,
    n.value('(@trunc)[1]', 'int') AS EventsTrunc,
    n.value('(value)[1]', 'varchar(max)') AS CallStack
FROM
    (SELECT CAST(target_data as XML) target_data
     FROM sys.dm_xe_sessions AS s
     JOIN sys.dm_xe_session_targets t
     ON s.address = t.event_session_address
       WHERE s.name = 'XeWaitsOnCMemThread'
     AND t.target_name = 'asynchronous_bucketizer') as tab
CROSS APPLY target_data.nodes('BucketizerTarget/Slot') as q(n) 