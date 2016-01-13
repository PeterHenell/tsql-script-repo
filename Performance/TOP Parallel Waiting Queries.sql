-- http://michaeljswart.com/2011/12/cxpacket-whats-that-and-whats-next/
-- TOP 20 parallel queries (by CPU)
-- TOP queries that elapse much more than they spend working. A sign of waiting for parallel threads to complete (CXPACKAGE)
-- total_worker_time = Total time On CPU. If 2 cores are being used then time is including time spent on both (x2).
-- total_elapsed_time = time spent running the query.
SELECT TOP (20)
    [Total CPU] = total_worker_time,
	[Total Elapsed Time] = total_elapsed_time,
	[Execution Count] = execution_count,
    [Avg Cores Per Execution] = avg_cores_per_execution,
    [Average CPU in microseconds] = cast(total_worker_time / (execution_count + 0.0) as money),
    [Average CPU in Seconds] = cast(total_worker_time / (execution_count + 0.0) as money) / 1000000,
    [Avg Elapsed More Than Worked Seconds] = worker_vs_elapsed / 1000000, 
    [Avg Elapsed Seconds] = (total_elapsed_time / execution_count * 1.0 ) / 1000000,
    [DB Name] = DB_NAME(ST.dbid),
    [Object Name] = OBJECT_NAME(ST.objectid, ST.dbid),
    [Query Text] = (SELECT [processing-instruction(q)] = CASE 
            WHEN [sql_handle] IS NULL THEN ' '
            ELSE (SUBSTRING(ST.TEXT,(QS.statement_start_offset + 2) / 2,
                (CASE 
                        WHEN QS.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX),ST.text)) * 2
                        ELSE QS.statement_end_offset
                        END - QS.statement_start_offset) / 2))
            END
			FOR XML PATH(''), type),
    [Query Plan] = qp.query_plan
FROM sys.dm_exec_query_stats QS
CROSS APPLY sys.dm_exec_sql_text([sql_handle]) ST
CROSS APPLY sys.dm_exec_query_plan ([plan_handle]) QP
CROSS APPLY (SELECT ( ( total_worker_time - total_elapsed_time ) / execution_count ) * 1.0) diff(worker_vs_elapsed)
CROSS APPLY (SELECT ( ( total_worker_time / total_elapsed_time ) ) ) avgs(avg_cores_per_execution)
WHERE total_elapsed_time < total_worker_time
	AND worker_vs_elapsed > 1000 -- average difference is more than a millisecond
ORDER BY total_worker_time DESC

