SET NOEXEC Off
-- http://sqlskills.com/blogs/jonathan/post/Finding-what-queries-in-the-plan-cache-use-a-specific-index.aspx

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IndexName AS NVARCHAR(128) = 'PK_FactContract';

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
    DENSE_RANK() OVER (ORDER BY handles.plan_handle) Q_RN,
    ROW_NUMBER() OVER (PARTITION BY handles.plan_handle ORDER BY (select NULL)) Op_RN,
    
    logicalOP.value('(@PhysicalOp)[1]', 'varchar(100)') AS physicalOp,
    logicalOP.value('(@EstimateRows)[1]', 'varchar(100)') AS EstimateRows,


    logicalOP.value('(./IndexScan/Object/@Table)[1]', 'varchar(100)') AS op_on_table,
    logicalOP.value('(./IndexScan/Object/@Index)[1]', 'varchar(100)') AS op_on_index,
    logicalOP.value('(./IndexScan/Object/@IndexKind)[1]', 'varchar(100)') AS op_idx_kind,
    logicalOP.value('(./IndexScan/@Ordered)[1]', 'int') AS op_Ordered,
    logicalOP.value('(./IndexScan/@ScanDirection)[1]', 'varchar(1)') AS op_ScanDirection,

    REPLACE(logicalOP.query(' 
            for $column in IndexScan/DefinedValues/DefinedValue/ColumnReference 
            return string($column/@Column) 
            ').value('.', 'varchar(max)'), ' ', ', ') AS [op_ref_columns] , 

    logicalOP.value('(./IndexScan/Object/@Database)[1]', 'varchar(100)') AS op_Database,
    logicalOP.value('(./IndexScan/Object/@Schema)[1]', 'varchar(100)') AS op_Schema,

    logicalOP.value('(@EstimateRows)[1]', 'varchar(100)') AS EstimateRows,
    logicalOP.value('(@EstimateIO)[1]', 'varchar(100)') AS EstimateIO,
    logicalOP.value('(@EstimateCPU)[1]', 'varchar(100)') AS EstimateCPU,
    logicalOP.value('(@AvgRowSize)[1]', 'varchar(100)') AS AvgRowSize,
    logicalOP.value('(@EstimatedTotalSubtreeCost)[1]', 'varchar(100)') AS EstimatedTotalSubtreeCost,
    logicalOP.value('(@TableCardinality)[1]', 'varchar(100)') AS TableCardinality,
    logicalOP.value('(@Parallel)[1]', 'varchar(100)') AS Parallel,
    logicalOP.value('(@EstimateRebinds)[1]', 'varchar(100)') AS EstimateRebinds,
    logicalOP.value('(@EstimateRewinds)[1]', 'varchar(100)') AS EstimateRewinds,
    logicalOP.value('(@EstimatedExecutionMode)[1]', 'varchar(100)') AS EstimatedExecutionMode,

    stmt.value('(@CardinalityEstimationModelVersion)[1]', 'varchar(100)') AS CE_Version,

    --seekPredicates.value('(./SeekPredicateNew/SeekKeys/Prefix/@ScanType)[1]', 'varchar(max)') AS seek_type,
    --scanPredicates.value('(./IndexScan/Object/@Schema)[1]', 'varchar(max)') AS op_Schema,
	stmt.value('(@StatementText)[1]', 'varchar(max)') AS SQL_Text, 
    stmt.value('(@StatementId)[1]', 'int') AS StatementId,
    stmt.query(' 
            for $simple in /ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple 
            return string($simple/@StatementText) 
            ').value('.', 'varchar(max)') AS [sql_all_txt] ,
	usecounts as [Use Count], 
	plan_handle, 
	query_plan,
    qstat.*
FROM handles
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt) 
CROSS APPLY stmt.nodes('.//IndexScan/Object[@Index=sql:variable("@IndexName")]') AS idx(obj) 
OUTER APPLY stmt.nodes('.//RelOp') as logicalOps(logicalOP)
OUTER APPLY (select stmt.value('(@StatementId)[1]', 'int')) AS id(StatementId)
OUTER APPLY (
     SELECT TOP 1
           --st.sql_handle ,
           --st.statement_start_offset ,
           --st.statement_end_offset ,
           --st.plan_generation_num ,
           --st.creation_time ,
           --st.last_execution_time ,
           st.execution_count ,
           st.total_worker_time ,
           --st.last_worker_time ,
           st.min_worker_time ,
           st.max_worker_time ,
           st.total_physical_reads ,
           --st.last_physical_reads ,
           st.min_physical_reads ,
           st.max_physical_reads ,
           st.total_logical_writes ,
           --st.last_logical_writes ,
           st.min_logical_writes ,
           st.max_logical_writes ,
           st.total_logical_reads ,
           --st.last_logical_reads ,
           st.min_logical_reads ,
           st.max_logical_reads ,
           --st.total_clr_time ,
           --st.last_clr_time ,
           --st.min_clr_time ,
           --st.max_clr_time ,
           st.total_elapsed_time ,
           --st.last_elapsed_time ,
           st.min_elapsed_time ,
           st.max_elapsed_time ,
           --st.query_hash ,
           --st.query_plan_hash ,
           st.total_rows ,
           st.last_rows ,
           st.min_rows ,
           st.max_rows ,
           --st.statement_sql_handle ,
           st.statement_context_id 
     FROM sys.dm_exec_query_stats st WHERE st.plan_handle = handles.plan_handle 
    ) qstat
--OUTER APPLY logicalOP.nodes('.//SeekPredicates') as seekPred(seekPredicates)
--OUTER APPLY logicalOP.nodes('.//Predicate') as scanPred(scanPredicates)
OPTION(MAXDOP 1, RECOMPILE);



SET NOEXEC ON   

SELECT * FROM sys.dm_exec_cached_plans 
WHERE plan_handle = '0x05000800C6BBEF2640613FF1020000000000000000000000'

