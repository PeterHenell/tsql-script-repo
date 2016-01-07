SELECT query_text.text
       session_id ,
       request_id ,
       start_time ,
       status ,
       wait_type ,
       wait_time ,
       wait_resource ,
       open_transaction_count ,
       transaction_id ,
       cpu_time ,
       total_elapsed_time ,
       reads ,
       writes ,
       logical_reads ,
       row_count ,
       granted_query_memory * 8 AS granted_query_memory_kb
      
FROM sys.dm_exec_requests
CROSS APPLY ( (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
        (CASE WHEN statement_end_offset = -1
            THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                ELSE statement_end_offset
            END - statement_start_offset)/2)
     FROM sys.dm_exec_sql_text(sql_handle))) AS query_text(text)
WHERE session_id > 50