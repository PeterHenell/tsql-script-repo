SELECT
    req.session_id,
    ses.login_name,
  --  statement_start_offset as stmt_start_offset,
            (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
                (CASE WHEN statement_end_offset = -1
                    THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                        ELSE statement_end_offset
                    END - statement_start_offset)/2)
             FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
    --, CAST(qp.query_plan AS XML) AS statementPlan
    , qp.query_plan  AS statementPlan
    , qplan.query_plan
    , req.reads
   -- , open_resultset_count
    , req.total_elapsed_time
    , req.cpu_time
   -- , nest_level
    , [trancount] = trans.open_transaction_count
    , blocking_session_id
    , [Paralellism] = 1.0 * req.cpu_time / (NULLIF(req.total_elapsed_time, 0) * 1.0 )
    , req.wait_time, req.wait_type
FROM sys.dm_exec_requests req
left outer join sys.dm_exec_sessions ses
    on req.session_id = ses.session_id
outer APPLY sys.dm_exec_query_plan(plan_handle)  qplan
LEFT outer JOIN sys.dm_tran_session_transactions trans
    ON trans.session_id = req.session_id
outer  APPLY sys.dm_exec_text_query_plan(plan_handle,
                                            req.statement_start_offset,
                                            req.statement_end_offset) qp
WHERE req.session_id <> @@SPID-- and req.session_id = 86


