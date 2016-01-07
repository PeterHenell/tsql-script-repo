SELECT TOP 100
       last_execution_time ,
       execution_count ,
       total_worker_time ,
       
       total_physical_reads ,
       max_physical_reads ,

       total_logical_writes ,
       max_logical_writes ,
       
       total_logical_reads ,
       max_logical_reads ,
       
       total_elapsed_time ,
       max_elapsed_time ,
    (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
        (CASE WHEN statement_end_offset = -1
            THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                ELSE statement_end_offset
            END - statement_start_offset)/2)
     FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
FROM sys.dm_exec_query_stats 
ORDER BY execution_count desc