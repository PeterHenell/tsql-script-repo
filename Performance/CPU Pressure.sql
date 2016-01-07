-- High Percentage of Signal Wait time would indicate high CPU pressure
SELECT SUM(signal_wait_time_ms) AS TotalSignalWaitTime ,
 ( SUM(CAST(signal_wait_time_ms AS NUMERIC(20, 2)))
 / SUM(CAST(wait_time_ms AS NUMERIC(20, 2))) * 100 )
 AS PercentageSignalWaitsOfTotalTime
FROM sys.dm_os_wait_stats


-- Lists the total number of tasks that
-- are assigned to each scheduler, as well as the number that are runnable. Other tasks on
-- the scheduler that are in the current_tasks_count but not the runnable_tasks_
-- count are ones that are either sleeping or waiting for a resource.
SELECT scheduler_id, current_tasks_count, runnable_tasks_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255

-- If the
--scheduler queue is currently long, it’s likely you’ll also see the SOS_SCHEDULER_YIELD
--wait type in queries against sys.dm_exec_requests and sys.dm_os_waiting_
--tasks.