select *, [label] from sys.dm_pdw_sql_requests
where status in ('Complete')
OPTION (LABEL = '');


select 	DENSE_RANK() over( order by r.request_id) as request_nbr,
		r.[label],
		login_name, r.request_id, r.status, r.submit_time, r.start_time, r.end_compile_time, r.total_elapsed_time, r.command, resource_class, 
		datediff(ms, r.submit_time, r.end_compile_time) as compile_secs,
		datediff(MINUTE, r.submit_time, sysdatetime()) as elapsed_minutes,
		rs.operation_type,	
		rs.location_type,
		rs.distribution_type,
		rs.step_index,
		rs.start_time as step_started_at,
		rs.total_elapsed_time as step_elapsed_time,
		rs.row_count
from sys.dm_pdw_exec_requests r
inner join sys.dm_pdw_exec_sessions s on r.session_id = s.session_id 
inner join sys.dm_pdw_request_steps rs on rs.request_id = r.request_id
where 1=1
		--and r.status not in ('Completed', 'Failed', 'Cancelled')
		and login_name like  'JMETER_%'
order by 1, step_index 

