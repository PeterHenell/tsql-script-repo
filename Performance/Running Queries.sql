SELECT  query_text.[statementText] ,
        session_id ,
        --request_id ,
        start_time ,
        status ,
        wait_type ,
        wait_time ,
        wait_resource ,
        [Tran Count] = open_transaction_count ,
        transaction_id ,
        cpu_time ,
        [Elapsed] = total_elapsed_time ,
        reads ,
        writes ,
        logical_reads ,
        row_count ,
        [Granted KB] = granted_query_memory * 8,
        [objectName],
        [fullText],
        [Statment Plan] = text_plan.query_plan,
        [Query Plan] = qplan.query_plan
        
FROM    sys.dm_exec_requests req
        OUTER  APPLY ( ( SELECT  
                [objectName]  = OBJECT_NAME(objectid),
                [fullText] = text,
                [statementText] = SUBSTRING(text, statement_start_offset / 2 + 1,
                                          ( CASE WHEN statement_end_offset = -1
                                                 THEN LEN(CONVERT(NVARCHAR(MAX), text)) * 2
                                                 ELSE statement_end_offset
                                            END - statement_start_offset ) / 2)
                        FROM    sys.dm_exec_sql_text(sql_handle)
                      ) ) AS query_text 
OUTER APPLY sys.dm_exec_text_query_plan(req.plan_handle, statement_start_offset, statement_end_offset) text_plan
OUTER APPLY sys.dm_exec_query_plan(req.plan_handle) qplan
WHERE   session_id > 50
        AND session_id <> @@spid
        AND [fullText] IS NOT NULL;