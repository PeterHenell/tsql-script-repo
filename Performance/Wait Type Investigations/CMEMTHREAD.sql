-- https://blogs.technet.microsoft.com/sqlcontent/2012/12/20/how-it-works-cmemthread-and-debugging-them/
-- If you see the top consumers being of type ‘Partitioned by Node.’,  you may use startup, trace flag 8048 to further partition by CPU.

SELECT
type, pages_in_bytes,
CASE
WHEN (0x20 = creation_options & 0x20) THEN 'Global PMO. Cannot be partitioned by CPU/NUMA Node. TF 8048 not applicable.'
WHEN (0x40 = creation_options & 0x40) THEN 'Partitioned by CPU.TF 8048 not applicable.'
WHEN (0x80 = creation_options & 0x80) THEN 'Partitioned by Node. Use TF 8048 to further partition by CPU'
ELSE 'UNKNOWN'
END
from sys.dm_os_memory_objects
order by pages_in_bytes DESC


-- CMEMTHREAD can show up in the running queries if it is a bottleneck of the server.
select r.session_id,r.wait_type,r.wait_time,r.wait_resource
from sys.dm_exec_requests r
join sys.dm_exec_sessions s
on s.session_id=r.session_id and s.is_user_process=1 