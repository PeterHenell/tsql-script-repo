DECLARE @dbname     SYSNAME = 'dwh_base',
        @schema     SYSNAME = 'dwh',
        @procname   SYSNAME = 'fnContractCounterparts';
DECLARE @objectID INT = OBJECT_ID(CONCAT(@dbname, '.', @schema, '.', @procname));

IF @objectID IS NULL  RAISERROR ('invalid object name', 16, 1) WITH NOWAIT;

WITH basedata AS (
   SELECT qs.plan_handle,
            qs.statement_start_offset/2 AS stmt_start,
          qs.statement_end_offset/2 AS stmt_end,
          est.encrypted AS isencrypted, est.text AS sqltext,
          epa.value AS set_options, qp.query_plan,
          charindex('<ParameterList>', qp.query_plan) + len('<ParameterList>')
             AS paramstart,
          charindex('</ParameterList>', qp.query_plan) AS paramend
   FROM   sys.dm_exec_query_stats qs
   CROSS  APPLY sys.dm_exec_sql_text(qs.sql_handle) est
   CROSS  APPLY sys.dm_exec_text_query_plan(qs.plan_handle,
                                            qs.statement_start_offset,
                                            qs.statement_end_offset) qp
   CROSS  APPLY sys.dm_exec_plan_attributes(qs.plan_handle) epa
   WHERE  est.objectid  = @objectID
     AND  est.dbid      = DB_ID(@dbname)
     AND  epa.attribute = 'set_options'
), next_level AS (
   SELECT plan_handle,stmt_start, set_options, query_plan,
          CASE WHEN isencrypted = 1 THEN '-- ENCRYPTED'
               WHEN stmt_start >= 0
               THEN substring(sqltext, stmt_start + 1,
                              CASE stmt_end
                                   WHEN 0 THEN datalength(sqltext)
                                   ELSE stmt_end - stmt_start + 1
                              END)
          END AS Statement,
          CASE WHEN paramend > paramstart
               THEN CAST (substring(query_plan, paramstart,
                                   paramend - paramstart) AS xml)
          END AS params
   FROM   basedata
)

SELECT set_options AS [SET]
        , n.stmt_start AS Pos
        , n.Statement
       , CR.c.value('@Column', 'nvarchar(128)') AS Parameter
       , CR.c.value('@ParameterCompiledValue', 'nvarchar(128)') AS [Sniffed Value]
       , CAST (query_plan AS xml) AS [Query plan]
       , n.plan_handle
FROM   next_level n
CROSS  APPLY   
        n.params.nodes('ColumnReference') AS CR(c)
ORDER  BY n.set_options, n.stmt_start, Parameter