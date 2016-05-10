DECLARE @dbname     SYSNAME = 'dwh_base',
        @schema     SYSNAME = 'dwh',
        @procname   SYSNAME = 'fnContractCounterparts';
DECLARE @objectID INT = OBJECT_ID(CONCAT(@dbname, '.', @schema, '.', @procname));

IF @objectID IS NULL  RAISERROR ('invalid object name', 16, 1) WITH NOWAIT;


   SELECT qs.plan_handle,
          qs.statement_start_offset/2 AS stmt_start,
          qs.statement_end_offset/2 AS stmt_end,
          est.text AS sqltext,
          epa.attribute,
          epa.value
   FROM   sys.dm_exec_query_stats qs
   CROSS  APPLY sys.dm_exec_sql_text(qs.sql_handle) est
   CROSS  APPLY sys.dm_exec_text_query_plan(qs.plan_handle,
                                            qs.statement_start_offset,
                                            qs.statement_end_offset) qp
   CROSS  APPLY sys.dm_exec_plan_attributes(qs.plan_handle) epa
   WHERE  est.objectid  = @objectID
     AND  est.dbid      = DB_ID(@dbname)
     AND epa.attribute IN ( 'hits_exec_context', -- Number of times the execution context was obtained from the plan cache and reused, saving the overhead of recompiling the SQL statement. The value is an aggregate for all batch executions so far.
                            'user_id', -- Value of -2 indicates that the batch submitted does not depend on implicit name resolution and can be shared among different users. This is the preferred method. Any other value represents the user ID of the user submitting the query in the database.
                            'inuse_exec_context', -- Number of currently executing batches that are using the query plan.
                            'misses_exec_context', -- Number of times that an execution context could not be found in the plan cache, resulting in the creation of a new execution context for the batch execution.
                            'free_exec_context', -- Number of cached execution contexts for the query plan that are not being currently used.
                            'removed_exec_context', -- Number of execution contexts that have been removed because of memory pressure on the cached plan.
                            'inuse_cursors', -- Number of currently executing batches containing one or more cursors that are using the cached plan.
                            'hits_cursors', -- Number of times that an inactive cursor was obtained from the cached plan and reused. The value is an aggregate for all batch executions so far.
                            'misses_cursors', -- Number of times that an inactive cursor could not be found in the cache.
                            'removed_cursors', -- Number of cursors that have been removed because of memory pressure on the cached plan.
                            'merge_action_type') -- The type of trigger execution plan used as the result of a MERGE statement.
                                                 -- 0 indicates a non-trigger plan, a trigger plan that does not execute as the result of a MERGE statement, or a trigger plan that executes as the result of a MERGE statement that only specifies a DELETE action.
                                                 -- 1 indicates an INSERT trigger plan that runs as the result of a MERGE statement.
                                                 -- 2 indicates an UPDATE trigger plan that runs as the result of a MERGE statement.
                                                 -- 3 indicates a DELETE trigger plan that runs as the result of a MERGE statement containing a corresponding INSERT or UPDATE action.
                                                 -- For nested triggers run by cascading actions, this value is the action of the MERGE statement that caused the cascade.