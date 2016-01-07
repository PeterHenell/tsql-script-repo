-- http://www.jasonstrate.com/2011/01/can-you-dig-it-find-estimated-rowcounts/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
GO

WITH XMLNAMESPACES
    (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
,cEstimatedRows
AS (
    SELECT TOP 25 
        c.value('@StatementEstRows', 'float') AS StatementEstRows
        ,cp.usecounts
        ,c.value('@StatementSubTreeCost', 'float') AS StatementSubTreeCost
        ,c.value('@StatementType', 'varchar(255)') AS StatementType
        ,CAST('<?query --' + CHAR(13) + c.value('@StatementText', 'varchar(max)') + CHAR(13) + '--?>' AS xml) AS StatementText
        ,cp.plan_handle
        ,qp.query_plan
        ,c.value('xs:hexBinary(substring(@QueryHash,3))','binary(8)') AS query_hash
        ,c.query('.') query
    FROM sys.dm_exec_cached_plans AS cp
    CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
    CROSS APPLY qp.query_plan.nodes('//StmtSimple') t(c)
    WHERE qp.query_plan.exist('//StmtSimple') = 1
    ORDER BY c.value('@StatementEstRows', 'float') DESC
),cQueryStats
AS (
SELECT query_hash
    ,SUM(total_worker_time / NULLIF(qs.execution_count,0)) AS avg_worker_time
    ,SUM(total_logical_reads / NULLIF(qs.execution_count,0)) AS avg_logical_reads
    ,SUM(total_elapsed_time / NULLIF(qs.execution_count,0)) AS avg_elapsed_time
FROM sys.dm_exec_query_stats qs
GROUP BY query_hash
)
SELECT er.StatementEstRows
, er.usecounts
, er.StatementSubTreeCost
, qs.avg_worker_time
, qs.avg_logical_reads
, qs.avg_elapsed_time
, er.StatementType
, er.StatementText
, er.query_plan
, er.plan_handle
FROM cEstimatedRows er
    LEFT OUTER JOIN cQueryStats qs ON er.query_hash = qs.query_hash
GO

