SELECT
    p.*,
	l_blocked.request_session_id AS blocked_session_id,
	l_blocked.request_request_id AS blocked_request_id,
	l_blocked.request_exec_context_id AS blocked_exec_context_id,
	l_blocked.request_mode AS blocked_request_mode,	
	wt_blocked.wait_duration_ms AS blocked_wait_duration,
	l_blocker.request_session_id AS blocker_session_id,
	l_blocker.request_request_id AS blocker_request_id,
	l_blocker.request_exec_context_id AS blocker_exec_context_id,
	l_blocker.request_mode AS blocker_request_mode,
	l_blocker.request_status AS blocker_lock_status,
	wt_blocked.resource_description AS blocked_resource
FROM sys.dm_os_waiting_tasks AS wt_blocked
INNER JOIN sys.dm_tran_locks AS l_blocked ON
	l_blocked.lock_owner_address = wt_blocked.resource_address
INNER JOIN sys.dm_os_tasks AS t_blocker ON 
	t_blocker.task_address = wt_blocked.blocking_task_address
INNER JOIN sys.dm_tran_locks AS l_blocker ON
	l_blocker.request_session_id = t_blocker.session_id
	AND l_blocker.request_request_id = t_blocker.request_id
	AND l_blocker.request_exec_context_id = t_blocker.exec_context_id

 LEFT JOIN sys.partitions p 
    ON p.hobt_id = l_blocker.resource_associated_entity_id

WHERE
	wt_blocked.blocking_session_id <> wt_blocked.session_id
	AND l_blocker.resource_type = l_blocked.resource_type
	AND l_blocker.resource_database_id = l_blocked.resource_database_id
	AND l_blocker.resource_associated_entity_id = l_blocked.resource_associated_entity_id
	AND l_blocker.resource_description = l_blocked.resource_description

--    SELECT DB_NAME(13)

--USE DWH_TEMP
--SELECT * FROM sys.objects WHERE object_id = 1125899909070848

--keylock hobtid=1125899909070848 dbid=13 id=lock1b30de880 mode=X associatedObjectId=1125899909070848


 --select 
 --            [db] = db_name(s1.[database_id]), 
 --            [waitresource] = ltrim(rtrim(s1.[wait_resource])),
 --            [table_name] = object_name(sl.rsc_objid),            
 --            [index_name] = si.[name],
 --            s1.[wait_time], 
 --            s1.[last_wait_type], 
 --            s1.[session_id],
 --            session1.[login_name], 
 --            session1.[host_name], 
 --            session1.[program_name], 
 --            [cmd] = isnull(st1.[text], ''),
 --            [query_plan] = isnull(qp1.[query_plan], ''),
 --            session1.[status],
 --            session1.[cpu_time], 
 --            s1.[lock_timeout],
 --            [blocked by] = s1.[blocking_session_id],             
 --            [login_name 2] = session2.[login_name],
 --            [hostname 2] = session2.[host_name],
 --            [program_name 2] = session2.[program_name],
 --            [cmd 2] = isnull(st2.[text], ''),
 --            [query_plan 2] = isnull(qp2.[query_plan], ''),
 --            session2.[status],
 --            session2.[cpu_time]          
 --      -- Process Requests
 --      from sys.dm_exec_requests (nolock) s1 
 --      outer apply sys.dm_exec_sql_text(s1.sql_handle) st1
 --      outer apply sys.dm_exec_query_plan(s1.plan_handle) qp1
 --      left outer join sys.dm_exec_requests (nolock) s2 on s2.[session_id] = s1.[blocking_session_id]
 --      outer apply sys.dm_exec_sql_text(s2.sql_handle) st2
 --      outer apply sys.dm_exec_query_plan(s2.plan_handle) qp2
 --      -- Sessions
 --      left outer join sys.dm_exec_sessions (nolock) session1 on session1.[session_id] = s1.[session_id]
 --      left outer join sys.dm_exec_sessions (nolock) session2 on session2.[session_id] = s1.[blocking_session_id]
 --      -- Lock-Info
 --      left outer join  master.dbo.syslockinfo (nolock) sl on s1.[session_id] = sl.req_spid
 --      -- Indexes
 --      left outer join sys.indexes (nolock) si on sl.rsc_objid = si.[object_id] and sl.rsc_indid = si.[index_id]
 --      where s1.[blocking_session_id] <> 0 
 --            and (sl.rsc_type in (2,3,4,5,6,7,8,9)) and sl.req_status = 3
 --            --and s1.[wait_time] >= @threshold