--Table Index Usage
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @TableName SYSNAME = '[ShiverMeTuples]'; 
DECLARE @DatabaseName SYSNAME;
 
SELECT @DatabaseName = '[' + DB_NAME() + ']';
 
WITH XMLNAMESPACES
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
    n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text,
    --n.query('.'),
    cp.plan_handle,
    i.value('(@PhysicalOp)[1]', 'VARCHAR(128)') AS PhysicalOp,
    i.value('(@EstimateRows)[1]', 'VARCHAR(128)') AS EstimateRows,
    i.value('(@EstimateIO)[1]', 'VARCHAR(128)') AS EstimateIO,
    i.value('(@EstimateCPU)[1]', 'VARCHAR(128)') AS EstimateCPU,
	cp.usecounts,
    i.value('(./IndexScan/@Lookup)[1]', 'VARCHAR(128)') AS IsLookup,
    i.value('(./IndexScan/Object/@Database)[1]', 'VARCHAR(128)') AS DatabaseName,
    i.value('(./IndexScan/Object/@Schema)[1]', 'VARCHAR(128)') AS SchemaName,
    i.value('(./IndexScan/Object/@Table)[1]', 'VARCHAR(128)') AS TableName,
    i.value('(./IndexScan/Object/@Index)[1]', 'VARCHAR(128)') as IndexName,
    --i.query('.'),
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./OutputList/ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS output_columns,
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./IndexScan/SeekPredicates/SeekPredicateNew//ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS seek_columns,
    RIGHT(i.value('(./IndexScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)'), len(i.value('(./IndexScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)')) - charindex('.', i.value('(./IndexScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)'))) as Predicate,
    query_plan
FROM (  SELECT plan_handle, query_plan
        FROM (  SELECT DISTINCT plan_handle
                FROM sys.dm_exec_query_stats WITH(NOLOCK)) AS qs
        OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp
      ) as tab (plan_handle, query_plan)
INNER JOIN sys.dm_exec_cached_plans AS cp 
    ON tab.plan_handle = cp.plan_handle
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/*') AS q(n)
CROSS APPLY n.nodes('.//RelOp[IndexScan/Object[@Table=sql:variable("@TableName") and @Database=sql:variable("@DatabaseName")]]' ) as s(i)
--WHERE i.value('(./IndexScan/@Lookup)[1]', 'VARCHAR(128)') = 1
ORDER BY 3 
OPTION(RECOMPILE, MAXDOP 4);

 GO
 -- Table (Heap) Scans
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @TableName SYSNAME = '[ItsAHeapOfSomething]'; 
DECLARE @DatabaseName SYSNAME;
 
SELECT @DatabaseName = '[' + DB_NAME() + ']';
 
WITH XMLNAMESPACES
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
    n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text,
    n.query('.'),
    cp.plan_handle,
    i.value('(@PhysicalOp)[1]', 'VARCHAR(128)') AS PhysicalOp,
    i.value('(./TableScan/@Lookup)[1]', 'VARCHAR(128)') AS IsLookup,
    i.value('(./TableScan/Object/@Database)[1]', 'VARCHAR(128)') AS DatabaseName,
    i.value('(./TableScan/Object/@Schema)[1]', 'VARCHAR(128)') AS SchemaName,
    i.value('(./TableScan/Object/@Table)[1]', 'VARCHAR(128)') AS TableName,
    --i.value('(./TableScan/Object/@Table)[1]', 'VARCHAR(128)') as TableName,
    i.query('.'),
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./OutputList/ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS output_columns,
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./TableScan/SeekPredicates/SeekPredicateNew//ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS seek_columns,
    RIGHT(i.value('(./TableScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)'), len(i.value('(./TableScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)')) - charIndex('.', i.value('(./TableScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)'))) as Predicate,
	cp.usecounts,
    query_plan
FROM (  SELECT plan_handle, query_plan
        FROM (  SELECT DISTINCT plan_handle
                FROM sys.dm_exec_query_stats WITH(NOLOCK)) AS qs
        OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp
      ) as tab (plan_handle, query_plan)
INNER JOIN sys.dm_exec_cached_plans AS cp 
    ON tab.plan_handle = cp.plan_handle
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/*') AS q(n)
CROSS APPLY n.nodes('.//RelOp[TableScan/Object[@Table=sql:variable("@TableName") and @Database=sql:variable("@DatabaseName")]]' ) as s(i)
--WHERE i.value('(./TableScan/@Lookup)[1]', 'VARCHAR(128)') = 1
OPTION(RECOMPILE, MAXDOP 4);