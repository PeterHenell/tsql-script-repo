select *
from sys.dm_os_memory_cache_counters
where type = 'CACHESTORE_SQLCP' or type = 'CACHESTORE_OBJCP'

select usecounts, cacheobjtype, objtype, bucketid, text
from sys.dm_exec_cached_plans cp cross apply
sys.dm_exec_sql_text(cp.plan_handle)
where cacheobjtype = 'Compiled Plan'
order by objtype DESC   