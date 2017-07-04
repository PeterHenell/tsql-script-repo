select
    act.transaction_id,
    [@@trancount] = st.open_transaction_count,
    act.name,
    act.transaction_begin_time,
    transaction_state = case act.transaction_state
        when 0 THEN 'The transaction has not been completely initialized yet.'
        WHEN 1 THEN 'The transaction has been initialized but has not started.'
        WHEN 2 THEN 'The transaction is active.'
        WHEN 3 THEN 'The transaction has ended. This is used for read-only transactions.'
        WHEN 4 THEN 'The commit process has been initiated on the distributed transaction. This is for distributed transactions only. The distributed transaction is still active but further processing cannot take place.'
        WHEN 5 THEN 'The transaction is in a prepared state and waiting resolution.'
        WHEN 6 THEN 'The transaction has been committed.'
        WHEN 7 THEN 'The transaction is being rolled back.'
        WHEN 8 THEN 'The transaction has been rolled back.'
    else 'unknown state see https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql'
    end,
    st.session_id,
    req.request_id,
    req.status,
    req.command,
    req.database_id,
    req.user_id,
    req.blocking_session_id,
    req.wait_type,
    req.wait_time,
    req.last_wait_type,
    req.open_transaction_count,
    req.cpu_time,
    req.total_elapsed_time,
    req.scheduler_id,
    req.reads,
    req.logical_reads,
    req.writes,
    req.granted_query_memory,
    qplan.query_plan,
    [statement_plan] = qp.query_plan,
    query_text
from sys.dm_tran_session_transactions st
inner join sys.dm_tran_active_transactions act on act.transaction_id = st.transaction_id
left outer join sys.dm_exec_requests req on req.session_id = st.session_id

outer APPLY sys.dm_exec_query_plan(plan_handle)  qplan

outer  APPLY sys.dm_exec_text_query_plan(plan_handle,
                                            req.statement_start_offset,
                                            req.statement_end_offset) qp
outer apply  (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
                (CASE WHEN statement_end_offset = -1
                    THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                        ELSE statement_end_offset
                    END - statement_start_offset)/2)
             FROM sys.dm_exec_sql_text(sql_handle)) AS q(query_text)
