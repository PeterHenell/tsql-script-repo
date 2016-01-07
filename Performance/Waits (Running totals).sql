-- Accumulated running totals Waits
SELECT wait_type -- the type of wait, which generally indicates the resource on which the worked threads waited (typical resource waits include lock, latch disk I/O waits, and so on).
     , wait_time_ms -- total, cumulative amount of time that threads have waited on the associated wait type; this value includes the time in the signal_wait_time_ms column. The value increments from the moment a task stops execution to wait for a resource, to the point it resumes execution.
     , signal_wait_time_ms -- the total, cumulative amount of time threads took to start executing after being signaled; this is time spent on the runnable queue.
     , waiting_tasks_count -- the cumulative total number of waits that have occurred for the associated resource (wait_type).
     , max_wait_time_ms -- the maximum amount of time that a thread has been delayed, for a wait of this type.
FROM sys.dm_os_wait_stats


