select 
       --statement_start_offset ,
       --statement_end_offset ,
       --plan_generation_num ,
       --plan_handle ,
       --creation_time ,
       last_execution_time ,
       execution_count ,
       total_worker_time ,
       total_elapsed_time ,

       --last_worker_time ,
       --min_worker_time ,
       --max_worker_time ,
       --total_physical_reads ,
       --last_physical_reads ,
       --min_physical_reads ,
       --max_physical_reads ,
       --total_logical_writes ,
       --last_logical_writes ,
       --min_logical_writes ,
       --max_logical_writes ,
       --total_logical_reads ,
       --last_logical_reads ,
       --min_logical_reads ,
       --max_logical_reads ,
       --total_clr_time ,
       --last_clr_time ,
       --min_clr_time ,
       --max_clr_time ,
       
       --last_elapsed_time ,
       --min_elapsed_time ,
       --max_elapsed_time ,
       --query_hash ,
       --query_plan_hash ,
       --total_rows ,
       last_rows ,
       min_rows ,
       max_rows-- ,
       --statement_sql_handle ,
       --statement_context_id 
FROM sys.dm_exec_query_stats 
                    -- total_worker_time is measured to the microsecond, but is accurate to the millisecond so:
CROSS APPLY (SELECT ( ( total_worker_time - total_elapsed_time ) / execution_count ) * 1.0) diff(worker_vs_elapsed)
where 
    total_elapsed_time < total_worker_time
	and worker_vs_elapsed > 1000 -- avg difference is at least 1 ms
    ORDER BY worker_vs_elapsed desc