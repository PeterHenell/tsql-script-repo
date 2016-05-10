--Configure query for profiling with sys.dm_exec_query_profiles
SET STATISTICS PROFILE ON;
GO

--Next, run your query in this session


-- In another session, monitor the progress of the session using this query
SELECT  
       node_id,physical_operator_name, 
       SUM(row_count) row_count, 
       SUM(estimate_row_count) AS estimate_row_count, 
       CAST(CAST(SUM(row_count) * 100 AS float) / SUM(estimate_row_count) AS DECIMAL(38,2)) [Estimated Completion]
FROM sys.dm_exec_query_profiles 
GROUP BY node_id,physical_operator_name
ORDER BY node_id;