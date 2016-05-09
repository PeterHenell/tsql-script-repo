SELECT
    statement_start_offset as stmt_start_offset,
    (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
        (CASE WHEN statement_end_offset = -1
            THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                ELSE statement_end_offset
            END - statement_start_offset)/2)
     FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
         , qplan.query_plan
         , reads
         , open_resultset_count
         , total_elapsed_time
         , cpu_time
         , nest_level
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_query_plan(plan_handle)  qplan
--WHERE session_id = 103 

