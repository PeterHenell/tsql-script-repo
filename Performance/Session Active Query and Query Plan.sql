SELECT
    req.session_id,
    statement_start_offset as stmt_start_offset,
            (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
                (CASE WHEN statement_end_offset = -1
                    THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                        ELSE statement_end_offset
                    END - statement_start_offset)/2)
             FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
    , CAST(qp.query_plan AS XML) AS statementPlan
    , qplan.query_plan
    , reads
    , open_resultset_count
    , total_elapsed_time
    , cpu_time
    , nest_level
    , trans.open_transaction_count
    
FROM sys.dm_exec_requests req
CROSS APPLY sys.dm_exec_query_plan(plan_handle)  qplan
LEFT outer JOIN sys.dm_tran_session_transactions trans
    ON trans.session_id = req.session_id
CROSS  APPLY sys.dm_exec_text_query_plan(plan_handle,
                                            req.statement_start_offset,
                                            req.statement_end_offset) qp
WHERE req.session_id <> @@SPID -- and req.session_id = 56


