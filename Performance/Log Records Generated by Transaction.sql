--http://jongurgul.com/blog/transaction-log-usage-session-id/ 
SELECT  
 [DBName] = DB_NAME(tdt.[database_id])  
,[RecoveryModel] = d.[recovery_model_desc]  
,[LogReuseWait] = d.[log_reuse_wait_desc]  
--,[OriginalLoginName] = es.[original_login_name]  
--,[ProgramName] = es.[program_name]  
,[SessionID] = es.[session_id]  
,[BlockingSessionId] = er.[blocking_session_id]  
,[WaitType] = er.[wait_type] 
,[LastWaitType] = er.[last_wait_type]  
,[Status] = er.[status]  
,[TranID] = tat.[transaction_id]  
,[TranBeginTime] = tat.[transaction_begin_time]  
,[DatabaseTransactionBeginTime] = tdt.[database_transaction_begin_time]  
--,tst.[open_transaction_count] [OpenTransactionCount] --Not present in SQL 2005 
,[DatabaseTransactionStateDesc] = CASE tdt.[database_transaction_state] 
        WHEN 1 THEN 'The transaction has not been initialized.' 
        WHEN 3 THEN 'The transaction has been initialized but has not generated any log records.' 
        WHEN 4 THEN 'The transaction has generated log records.' 
        WHEN 5 THEN 'The transaction has been prepared.' 
        WHEN 10 THEN 'The transaction has been committed.' 
        WHEN 11 THEN 'The transaction has been rolled back.' 
        WHEN 12 THEN 'The transaction is being committed. In this state the log record is being generated, but it has not been materialized or persisted.' 
        ELSE NULL --http://msdn.microsoft.com/en-us/library/ms186957.aspx 
     END 
,[StatementText] = est.[text]  
,er.row_count
,[LogRecordCount] = tdt.[database_transaction_log_record_count]  
,[LogBytesUsed MB]= tdt.[database_transaction_log_bytes_used]  / 1024 / 1024
,[LogBytesReserved MB] = tdt.[database_transaction_log_bytes_reserved]  / 1024 / 1024
,[LogBytesUsedSystem MB] = tdt.[database_transaction_log_bytes_used_system]  / 1024 / 1024
,[BytesReservedSystem MB] = tdt.[database_transaction_log_bytes_reserved_system]  / 1024 / 1024
,mem.dop,mem.requested_memory_kb,mem.granted_memory_kb, mem.required_memory_kb, mem.used_memory_kb, mem.ideal_memory_kb
,[BeginLsn] = tdt.[database_transaction_begin_lsn]  
,[LastLsn]= tdt.[database_transaction_last_lsn] 
--,pl.query_plan
--,stPl.query_plan
FROM sys.dm_exec_sessions es 
INNER JOIN sys.dm_tran_session_transactions tst ON es.[session_id] = tst.[session_id] 
INNER JOIN sys.dm_tran_database_transactions tdt ON tst.[transaction_id] = tdt.[transaction_id] 
INNER JOIN sys.dm_tran_active_transactions tat ON tat.[transaction_id] = tdt.[transaction_id] 
INNER JOIN sys.databases d ON d.[database_id] = tdt.[database_id] 
LEFT OUTER JOIN sys.dm_exec_requests er ON es.[session_id] = er.[session_id] 
LEFT OUTER JOIN sys.dm_exec_connections ec ON ec.[session_id] = es.[session_id] 
LEFT OUTER JOIN sys.dm_exec_query_memory_grants mem ON mem.request_id = er.request_id AND mem.session_id = es.session_id
--AND ec.[most_recent_sql_handle] <> 0x 
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) est 
--OUTER APPLY sys.dm_exec_query_plan(ec.most_recent_sql_handle) pl
--OUTER APPLY sys.dm_exec_query_plan(er.plan_handle) pl
--OUTER APPLY sys.dm_exec_text_query_plan(er.plan_handle, er.statement_start_offset, er.statement_end_offset) stPl
--WHERE tdt.[database_transaction_state] >= 4 
ORDER BY SessionID

--SELECT * FROM sys.dm_exec_cached_plans
--SELECT * FROM sys.dm_exec_query_memory_grants
--SELECT * FROM sys.dm_exec_requests