WITH XMLNAMESPACES 
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')    
,  topQueries AS (
    SELECT TOP 20
        (total_logical_reads/execution_count) AS
                                     avg_logical_reads,
        (total_logical_writes/execution_count) AS
                                     avg_logical_writes,
        (total_physical_reads/execution_count)
                                     AS avg_phys_reads,
        execution_count,
        total_worker_time / 1000000 AS [Total Worker Seconds],
        total_elapsed_time / 1000000 AS [Total Elapsed Seconds],
        total_logical_reads,
        total_logical_writes,
        statement_start_offset as stmt_start_offset,
        statement_text,
        raw_sql,
        plan_handle
    FROM sys.dm_exec_query_stats 
    CROSS APPLY (SELECT text,
                                SUBSTRING(text, statement_start_offset/2 + 1,
                                                (CASE WHEN statement_end_offset = -1
                                                        THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
                                                      ELSE statement_end_offset
                                                 END - statement_start_offset)/2)
                         FROM sys.dm_exec_sql_text(sql_handle)
                        
                ) AS query(raw_sql, statement_text)
    WHERE raw_sql NOT LIKE '%showplan%'
    ORDER BY
      (total_logical_reads + total_logical_writes) DESC
)
, handles AS (SELECT QP.query_plan, QP.dbid, QP.objectid, tq.* 
              FROM topQueries tq
              CROSS APPLY sys.dm_exec_query_plan (tq.[plan_handle]) QP
    )
SELECT 
       DENSE_RANK() OVER (ORDER BY qp.plan_handle) Q_RN,
       ROW_NUMBER() OVER (PARTITION BY qp.plan_handle ORDER BY (select NULL)) Op_RN,
       qp.statement_text AS [Query_Text],
       qp.execution_count ,
       qp.avg_phys_reads ,
       qp.avg_logical_writes ,
       qp.avg_logical_reads,
       qp.[Total Worker Seconds],
       qp.[Total Elapsed Seconds],
       qp.total_logical_reads,
       qp.total_logical_writes,
       DB_NAME(qp.dbid) AS DBName,
       OBJECT_NAME(qp.objectid) AS Object_Name ,
    
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

	   stmt.value('(@StatementText)[1]', 'varchar(max)') AS Statement_Text, 
       stmt.value('(@StatementId)[1]', 'int') AS StatementId,
       CASE WHEN ROW_NUMBER() OVER (PARTITION BY qp.plan_handle ORDER BY (select NULL)) = 1 THEN raw_sql ELSE NULL end AS [batch_sql_txt] ,
       stmt.query(' 
               for $colref in //ColumnReference
               where  string-length($colref/@ParameterCompiledValue) > 0
               return concat(string($colref/@Column) , "=",
                             string($colref/@ParameterCompiledValue))
               ').value('.', 'varchar(max)') AS [compiled_param_vals] ,
	   CASE WHEN ROW_NUMBER() OVER (PARTITION BY qp.plan_handle ORDER BY (select NULL)) = 1 THEN query_plan ELSE NULL END AS query_plan
FROM handles qp
OUTER APPLY QP.query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt) 
OUTER APPLY stmt.nodes('.//RelOp') as logicalOps(logicalOP)
OUTER APPLY (select stmt.value('(@StatementId)[1]', 'int')) AS id(StatementId)


OPTION(MAXDOP 1, RECOMPILE)

