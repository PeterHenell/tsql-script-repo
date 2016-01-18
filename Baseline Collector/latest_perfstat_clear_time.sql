SELECT 
       latest.clear_time
FROM [sys].[dm_os_wait_stats]
CROSS APPLY (
    SELECT [sqlserver_start_time]
    FROM [sys].[dm_os_sys_info]) sqlserver(start_time)
CROSS APPLY 
    ( 
        SELECT MAX(measuredTime) 
        FROM (
                VALUES (sqlserver.start_time), 
                       (DATEADD(SS, - [wait_time_ms] / 1000, GETDATE()))
             ) tm(measuredTime)
    ) AS latest(clear_time)
WHERE [wait_type] = 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP';

