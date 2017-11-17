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
       [max elapsed seconds] = max_elapsed_time / 1000 / 1000 ,
       [last] = (SELECT FORMATMESSAGE('%I64d sec, %I64d krows, %I64d IO, %I64d DOP', last_elapsed_time / 1000 / 1000, last_rows / 1000, last_logical_reads, qstat.last_dop)),
       [max] = (SELECT FORMATMESSAGE('%I64d sec, %I64d krows, %I64d IO, %I64d DOP', max_elapsed_time / 1000 / 1000, max_rows / 1000, max_logical_reads, qstat.max_dop)),
       [total] = (SELECT FORMATMESSAGE('%I64d secs, %I64d krows, %I64d IO, %I64d DOP', total_elapsed_time / 1000 / 1000, total_rows / 1000, total_logical_reads, qstat.total_dop)),
    (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
        (CASE WHEN statement_end_offset = -1
            THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                ELSE statement_end_offset
            END - statement_start_offset)/2)
     FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
     --, pl.query_plan
     --, batch_plan.query_plan
     
FROM sys.dm_exec_query_stats qstat
--OUTER APPLY sys.dm_exec_query_plan(plan_handle) batch_plan
--OUTER APPLY sys.dm_exec_text_query_plan(plan_handle, statement_start_offset, statement_end_offset) pl
ORDER BY max_elapsed_time DESC
