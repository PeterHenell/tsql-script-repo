select 
    s.login_name,
    r.session_id, 
	r.status, 
	r.command,
	r.blocking_session_id,
	r.wait_type as [request_wait_type], 
	r.wait_time as [request_wait_time],
	t.wait_type as [task_wait_type],
	t.wait_duration_ms as [task_wait_time],
	t.blocking_session_id,
	t.resource_description,
    st.text
from sys.dm_exec_requests r
left join sys.dm_os_waiting_tasks t
	on r.session_id = t.session_id
LEFT JOIN sys.dm_exec_sessions s
    ON r.session_id = s.session_id
cross apply sys.dm_exec_sql_text(r.sql_handle) as st
where r.session_id >= 50
and r.session_id <> @@spid;


