SELECT TOP 10
    (total_logical_reads/execution_count) AS
                                 avg_logical_reads,
    (total_logical_writes/execution_count) AS
                                 avg_logical_writes,
    (total_physical_reads/execution_count)
                                 AS avg_phys_reads,
    execution_count,
    statement_start_offset as stmt_start_offset,
    (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
        (CASE WHEN statement_end_offset = -1
            THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                ELSE statement_end_offset
            END - statement_start_offset)/2)
     FROM sys.dm_exec_sql_text(sql_handle)) AS query_text,
         plan_handle
FROM sys.dm_exec_query_stats 
ORDER BY
  (total_logical_reads + total_logical_writes) DESC

