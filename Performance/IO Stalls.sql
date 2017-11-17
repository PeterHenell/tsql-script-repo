SELECT DB_NAME(fs.database_id) AS [Database Name],
       mf.physical_name,
       io_stall_read_ms,
       num_of_reads,
       CAST(io_stall_read_ms / (1.0 + num_of_reads) AS NUMERIC(10, 1)) AS [avg_read_stall_ms],
       io_stall_write_ms,
       num_of_writes,
       CAST(io_stall_write_ms / (1.0 + num_of_writes) AS NUMERIC(10, 1)) AS [avg_write_stall_ms],
       io_stall_read_ms + io_stall_write_ms AS [io_stalls],
       num_of_reads + num_of_writes AS [total_io],
       CAST((io_stall_read_ms + io_stall_write_ms) / (1.0 + num_of_reads + num_of_writes) AS NUMERIC(10, 1)) AS [avg_io_stall_ms]
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS fs
    INNER JOIN sys.master_files AS mf
        ON fs.database_id = mf.database_id
           AND fs.[file_id] = mf.[file_id]
ORDER BY avg_io_stall_ms DESC
OPTION (RECOMPILE);




-- The SPID which requested this data will be moved to SUSPENDED queue and will wait for I/O to be completed. 
-- Once Windows updates SQL Server that the posted I/O is completed, SQL Server will move the SPID which posted this I/O from SUSPENDED queue to RUNNABLE queue

-- Following query shows the number of pending I/Os that are waiting to be completed for the entire SQL Server instance:
SELECT SUM(pending_disk_io_count) AS [Number of pending I/Os] FROM sys.dm_os_schedulers 

-- Following query gives details about the stalled I/O count reported by the first query.
SELECT *  FROM sys.dm_io_pending_io_requests

--SELECT * FROM sys.database_files