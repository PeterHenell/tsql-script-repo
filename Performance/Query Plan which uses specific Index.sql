SET NOEXEC Off
-- http://sqlskills.com/blogs/jonathan/post/Finding-what-queries-in-the-plan-cache-use-a-specific-index.aspx

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IndexName AS NVARCHAR(128) = 'IX_TradeReportRepository';

-- Make sure the name passed is appropriately quoted 
IF (LEFT(@IndexName, 1) <> '[' AND RIGHT(@IndexName, 1) <> ']') SET @IndexName = QUOTENAME(@IndexName); 
--Handle the case where the left or right was quoted manually but not the opposite side 
IF LEFT(@IndexName, 1) <> '[' SET @IndexName = '['+@IndexName; 
IF RIGHT(@IndexName, 1) <> ']' SET @IndexName = @IndexName + ']';

-- Dig into the plan cache and find all plans using this index 
WITH XMLNAMESPACES 
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')    

, handles AS (
    SELECT  cp.plan_handle, 
            CAST(qp.query_plan AS XML) AS query_plan, 
            usecounts
    FROM sys.dm_exec_cached_plans AS cp 
    CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
)
SELECT 
	case isnull(s.value('(@ScanType)[1]', 'varchar(max)'), '') when '' then 'SCAN' else 'SEEK' end,
	stmt.value('(@StatementText)[1]', 'varchar(max)') AS SQL_Text, 
	obj.value('(@Database)[1]', 'varchar(128)') AS DatabaseName, 
	obj.value('(@Schema)[1]', 'varchar(128)') AS SchemaName, 
	obj.value('(@Table)[1]', 'varchar(128)') AS TableName, 
	obj.value('(@Index)[1]', 'varchar(128)') AS IndexName, 
	obj.value('(@IndexKind)[1]', 'varchar(128)') AS IndexKind,
	usecounts as [Use Count], 
	plan_handle, 
	query_plan
FROM handles
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt) 
cross APPLY stmt.nodes('.//IndexScan/Object[@Index=sql:variable("@IndexName")]') AS idx(obj) 
outer apply stmt.nodes('.//IndexScan/SeekPredicates/SeekPredicateNew/SeekKeys/Prefix') as seekPrd(s)
OPTION(MAXDOP 1, RECOMPILE);



SET NOEXEC ON   

SELECT * FROM sys.dm_exec_cached_plans 
WHERE plan_handle = '0x05000800C6BBEF2640613FF1020000000000000000000000'

