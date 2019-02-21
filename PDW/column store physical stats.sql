--https://docs.microsoft.com/sv-se/azure/sql-data-warehouse/sql-data-warehouse-memory-optimizations-for-columnstore-compression
with cte
as
(
	select   		 tb.[name]                    AS [logical_table_name]
			,        rg.[row_group_id]            AS [row_group_id]
			,        rg.[state]                   AS [state]
			,        rg.[state_desc]              AS [state_desc]
			,        rg.[total_rows]              AS [total_rows]
			,        rg.[trim_reason_desc]        AS trim_reason_desc
			,        mp.[physical_name]           AS physical_name
	FROM    sys.[schemas] sm
	JOIN    sys.[tables] tb               ON  sm.[schema_id]          = tb.[schema_id]                             
	JOIN    sys.[pdw_table_mappings] mp   ON  tb.[object_id]          = mp.[object_id]
	JOIN    sys.[pdw_nodes_tables] nt     ON  nt.[name]               = mp.[physical_name]
	JOIN    sys.[dm_pdw_nodes_db_column_store_row_group_physical_stats] rg      ON  rg.[object_id]     = nt.[object_id]
	                                                                            AND rg.[pdw_node_id]   = nt.[pdw_node_id]
	                                        AND rg.[distribution_id]    = nt.[distribution_id]                                          
)
select count(*) num_trimmed_groups, trim_reason_desc, logical_table_name
from cte
where trim_reason_desc <> 'NO_TRIM'
group by trim_reason_desc, logical_table_name
order by logical_table_name, trim_reason_desc;

--BULKLOAD: This trim reason is used when the incoming batch of rows for the load had less than 1 million rows. The engine will create compressed row groups if there are greater than 100,000 rows being inserted (as opposed to inserting into the delta store) but sets the trim reason to BULKLOAD. In this scenario, consider increasing your batch load window to accumulate more rows. Also, reevaluate your partitioning scheme to ensure it is not too granular as row groups cannot span partition boundaries.
--MEMORY_LIMITATION: To create row groups with 1 million rows, a certain amount of working memory is required by the engine. When available memory of the loading session is less than the required working memory, row groups get prematurely trimmed. The following sections explain how to estimate memory required and allocate more memory.
--DICTIONARY_SIZE: This trim reason indicates that rowgroup trimming occurred because there was at least one string column with wide and/or high cardinality strings. The dictionary size is limited to 16 MB in memory and once this limit is reached the row group is compressed. If you do run into this situation, consider isolating the problematic column into a separate table.
