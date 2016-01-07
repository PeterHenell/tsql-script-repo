--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--GO

--DECLARE @op sysname = 'Index Scan';
--DECLARE @IndexName sysname = 'IX_TradeReportRepository';

--WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
--SELECT
--cp.plan_handle
--,operators.value('(IndexScan/Object/@Schema)[1]','sysname') AS SchemaName
--,operators.value('(IndexScan/Object/@Table)[1]','sysname') AS TableName
--,operators.value('(IndexScan/Object/@Index)[1]','sysname') AS IndexName
--,operators.value('@PhysicalOp','nvarchar(50)') AS PhysicalOperator
--,cp.usecounts
--,qp.query_plan
--FROM sys.dm_exec_cached_plans cp
--CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
--CROSS APPLY query_plan.nodes('//RelOp') rel(operators)
--WHERE operators.value('@PhysicalOp','nvarchar(50)') IN ('Clustered Index Scan','Index Scan')
--AND operators.value('(IndexScan/Object/@Index)[1]','sysname') = QUOTENAME(@IndexName,'[');


--SELECT * FROM sys.dm_exec_cached_plans
GO
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCK_TIMEOUT 6000;
SET NOCOUNT OFF;
GO

/* declare variables */

IF OBJECT_ID('tempdb..#xmlPlans') IS NULL 
    CREATE TABLE #xmlPlans (
           handle varbinary(64), 
           schemaName sysname, 
           TableName sysname, 
           IndexName sysname, 
           Operator varchar(500), 
           useCount bigint, 
           query_plan xml);


IF OBJECT_ID('tempdb..#cachedPlans') IS NULL
    SELECT
           usecounts ,
           objtype ,
           plan_handle ,
           query_plan
    INTO #cachedPlans
    FROM sys.dm_exec_cached_plans
    CROSS APPLY sys.dm_exec_query_plan(plan_handle)  

SET NOCOUNT ON;

GO
DECLARE @IndexName sysname = 'IX_TradeReportRepository';
DECLARE @op sysname = 'Index Scan';

DECLARE @plan_handle VARBINARY(64),
        @usecounts BIGINT,
        @objtype NVARCHAR(50),
        @query_plan xml;


-- 4 minutes
--DECLARE PLAN_CURSOR CURSOR FAST_FORWARD READ_ONLY FOR 
--    SELECT usecounts, objtype, plan_handle, query_plan FROM #cachedPlans;

--OPEN PLAN_CURSOR;
--FETCH NEXT FROM PLAN_CURSOR INTO @usecounts, @objtype, @plan_handle, @query_plan;

--WHILE @@FETCH_STATUS = 0
--BEGIN
--    FETCH NEXT FROM PLAN_CURSOR INTO @usecounts, @objtype, @plan_handle, @query_plan;

--    WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
--    INSERT INTO #xmlPlans(handle, schemaName, TableName, IndexName, Operator, useCount, query_plan)
--    SELECT
--         @plan_handle
--        ,operators.value('(IndexScan/Object/@Schema)[1]','sysname') AS SchemaName
--        ,operators.value('(IndexScan/Object/@Table)[1]','sysname') AS TableName
--        ,operators.value('(IndexScan/Object/@Index)[1]','sysname') AS IndexName
--        ,operators.value('@PhysicalOp','nvarchar(50)') AS PhysicalOperator
--        ,@usecounts
--        ,@query_plan
--    FROM @query_plan.nodes('//RelOp') rel(operators)
--    WHERE operators.value('@PhysicalOp','nvarchar(50)') IN ('Clustered Index Scan','Index Scan')
--    AND operators.value('(IndexScan/Object/@Index)[1]','sysname') = QUOTENAME(@IndexName,'[')
--    OPTION (OPTIMIZE FOR (@query_plan = NULL));
--END

--CLOSE PLAN_CURSOR;
--DEALLOCATE PLAN_CURSOR;

    WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
    INSERT INTO #xmlPlans(handle, schemaName, TableName, IndexName, Operator, useCount, query_plan)
    SELECT
         plan_handle
        ,operators.value('(IndexScan/Object/@Schema)[1]','sysname') AS SchemaName
        ,operators.value('(IndexScan/Object/@Table)[1]','sysname') AS TableName
        ,operators.value('(IndexScan/Object/@Index)[1]','sysname') AS IndexName
        ,operators.value('@PhysicalOp','nvarchar(50)') AS PhysicalOperator
        ,usecounts
        ,query_plan
    FROM #cachedPlans 
    CROSS APPLY query_plan.nodes('//RelOp') rel(operators)
    WHERE operators.value('@PhysicalOp','nvarchar(50)') IN ('Clustered Index Scan','Index Scan')
    AND operators.value('(IndexScan/Object/@Index)[1]','sysname') = QUOTENAME(@IndexName,'[')

SELECT * 
FROM #xmlPlans