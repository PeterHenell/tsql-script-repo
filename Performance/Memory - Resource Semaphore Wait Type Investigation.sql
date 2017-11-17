-- Read for details
-- https://www.mssqltips.com/sqlservertip/2827/troubleshooting-sql-server-resourcesemaphore-waittype-memory-issues/

-- if resource semaphore is top
SELECT [Waiting Requests] = COUNT(*), wait_type, last_wait_type, [Total Wait Time] = SUM(wait_time) 
FROM sys.dm_exec_requests
WHERE wait_type IS NOT null
GROUP BY wait_type,
         last_wait_type
ORDER BY 1 desc, wait_type

-- Check if many queries are waiting to get allocated memory
SELECT [Query Type] = CASE resource_semaphore_id WHEN 0 THEN 'large queries' ELSE 'small queries' end,
       target_memory_kb,
       max_target_memory_kb,
       total_memory_kb,
       available_memory_kb,
       granted_memory_kb,
       used_memory_kb,
       [Active Queries which have been granted memory] = grantee_count,
       [Queries Waiting for Memory] = waiter_count,
       [Total number of time-out errors since server startup] = timeout_error_count,
       [forced minimum-memory grants since server startup] = forced_grant_count,
       pool_id 
FROM sys.dm_exec_query_resource_semaphores

--SELECT * FROM sys.dm_os_memory_clerks

-- Look at the queries which are waiting to get memory granted. (Are they too big or are they victims?)
SELECT session_id, request_id, dop, request_time, requested_memory_kb, required_memory_kb, query_cost, resource_semaphore_id, wait_order, wait_time_ms, text, query_plan
FROM sys.dm_exec_query_memory_grants 
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
OUTER APPLY sys.dm_exec_query_plan(plan_handle)
WHERE granted_memory_kb IS NULL-- OR granted_memory_kb < requested_memory_kb


-- Look at the who have allocated the most memory (They could be the reason other queries do not get memory)
SELECT TOP 10 
    session_id, request_id, dop, request_time, requested_memory_kb, required_memory_kb, granted_memory_kb, query_cost, resource_semaphore_id, wait_order, wait_time_ms, text, query_plan
FROM sys.dm_exec_query_memory_grants 
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
OUTER APPLY sys.dm_exec_query_plan(plan_handle)
ORDER BY granted_memory_kb desc


