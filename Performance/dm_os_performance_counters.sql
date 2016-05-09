SELECT  'dm_os_performance_counters'  AS key_col
        , [Page life expectancy] AS [Page_life_expectancy]
        , CAST([Buffer cache hit ratio] AS DECIMAL(28, 6)) / CAST([Buffer cache hit ratio base] AS DECIMAL(28, 6)) AS [Cache_Hit_Ratio]
        , CAST([Average Wait Time (ms)] AS DECIMAL(28, 6)) / CAST([Average Wait Time Base] AS DECIMAL(28, 6)) AS [Avarage_Lock_Wait_Time]
        , CAST([CPU usage %] AS DECIMAL(28, 6)) / CAST([CPU usage % base] AS DECIMAL(28, 6)) AS [CPU_Usage_%]
        , CAST([Avg Disk Read IO (ms)] AS DECIMAL(28, 6)) / CAST([Avg Disk Read IO (ms) base] AS DECIMAL(28, 6)) AS [Avg_Disk_Read_IO_(ms)]
        , CAST([Avg Disk Write IO (ms)] AS DECIMAL(28, 6)) / CAST([Avg Disk Write IO (ms) Base] AS DECIMAL(28, 6)) AS [Avg_Disk_Write_IO_(ms)]
, [Page lookups/sec] AS [Page_lookups/sec]
, [Lazy writes/sec] AS [Lazy_writes/sec]
, [Readahead pages/sec] AS [Readahead_pages/sec]
, [Readahead time/sec] AS [Readahead_time/sec]
, [Page reads/sec] AS [Page_reads/sec]
, [Page writes/sec] AS [Page_writes/sec]
, [Free list stalls/sec] AS [Free_list_stalls/sec]
, 100 * (CAST([Free list stalls/sec] AS DECIMAL(28, 6)) / CAST([Page reads/sec]  AS DECIMAL(28, 6))) AS [Readahead_%_of_Reads/sec]
, 20.0 AS [Readahead_%_of_Reads/sec_Threshold]
, [Transactions/sec] AS [Transactions/sec]
, [Number of Deadlocks/sec] AS [Number_of_Deadlocks/sec]
, [SQL Compilations/sec] AS [SQL_Compilations/sec]
, [SQL Re-Compilations/sec] AS [SQL_Re-Compilations/sec]
, [Batch Requests/sec] AS [Batch_Requests/sec]
, [Full Scans/sec] AS [Full_Scans/sec]
, [Page Splits/sec] AS [Page_Splits/sec]
FROM 
(
    SELECT cntr_value, RTRIM(counter_name) AS counter_name
    FROM sys.dm_os_performance_counters 
    WHERE 
        (object_name = 'SQLServer:Locks' AND counter_name IN('Average Wait Time Base', 'Average Wait Time (ms)') AND instance_name = '_Total')
        OR
        (object_name = 'SQLServer:Workload Group Stats' AND counter_name IN('CPU usage %', 'CPU usage % base') AND instance_name = 'default')
        OR
        (object_name = 'SQLServer:Resource Pool Stats' AND counter_name IN('Avg Disk Read IO (ms)', 'Avg Disk Read IO (ms) Base') AND instance_name = 'default')
         OR
        (object_name = 'SQLServer:Resource Pool Stats' AND counter_name IN('Avg Disk Write IO (ms)', 'Avg Disk Write IO (ms) Base') AND instance_name = 'default')
         OR
        (object_name = 'SQLServer:Buffer Manager' AND counter_name IN('Buffer cache hit ratio', 'Buffer cache hit ratio base'))
         OR
        (object_name = 'SQLServer:Access Methods' AND counter_name IN('Full Scans/sec', 'Page Splits/sec'))
        OR
        (counter_name = 'Transactions/sec' AND instance_name = '_Total')
        OR 
        (counter_name IN ('Page lookups/sec', 'Lazy writes/sec', 'Readahead pages/sec', 
                            'Readahead time/sec', 'Page reads/sec', 'Page writes/sec', 
                            'Free list stalls/sec', 
                            'Number of Deadlocks/sec', 'SQL Compilations/sec', 'SQL Re-Compilations/sec', 
                            'Batch Requests/sec', 'Buffer cache hit ratio base', 'Page life expectancy')  
        )
) src
PIVOT ( 
    SUM(cntr_value) 
    FOR counter_name IN ( [Average Wait Time (ms)]
                        , [Average Wait Time Base]
                        , [Avg Disk Read IO (ms) Base]
                        , [Avg Disk Read IO (ms)]
                        , [Avg Disk Write IO (ms) Base]
                        , [Avg Disk Write IO (ms)]
                        , [Batch Requests/sec]
                        , [Buffer cache hit ratio base]
                        , [Buffer cache hit ratio]
                        , [CPU usage % base]
                        , [CPU usage %]
                        , [Free list stalls/sec]
                        , [Lazy writes/sec]
                        , [Number of Deadlocks/sec]
                        , [Page lookups/sec]
                        , [Page reads/sec]
                        , [Page writes/sec]
                        , [Readahead pages/sec]
                        , [Readahead time/sec]
                        , [SQL Compilations/sec]
                        , [SQL Re-Compilations/sec]
                        , [Transactions/sec]
                        , [Page life expectancy]
                        , [Full Scans/sec]
                        , [Page Splits/sec]
                        )
    ) AS pivoted




  SELECT RTRIM(object_name) ,
        RTRIM(counter_name) ,
        RTRIM(instance_name) ,
        RTRIM(cntr_value) ,
        RTRIM(cntr_type)
    FROM sys.dm_os_performance_counters 
    WHERE counter_name LIKE '%Transactions/sec%' 
    
                                                                                                                                                                                                            


-- http://sqlserver-dba.co.uk/performance-tuning/sql-server-memory/buffer-manager-memory-performance-counters


