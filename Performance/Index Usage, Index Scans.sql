SELECT o.name, i.name, ius.* 
FROM sys.dm_db_index_usage_stats ius
INNER JOIN sys.objects o ON o.object_id = ius.object_id
LEFT OUTER JOIN sys.indexes i ON i.index_id = ius.index_id AND i.object_id = ius.object_id
ORDER BY user_scans DESC



--SELECT * FROM sys.dm_db_index_physical_stats(NULL, NULL, NULL, NULL, null)

--drop table #tmp

SELECT
    SCHEMA_NAME(o.schema_id) AS SchemaName
   ,OBJECT_NAME(o.object_id) AS TableName
   ,ISNULL(i.name, '---') AS IndexName
   ,SUBSTRING(i.type_desc, 0, 2) type_desc
   ,ISNULL(Index_Columns.index_columns_key, '---') AS index_columns_key
   ,ISNULL(Index_Columns.index_columns_include, '---') AS index_columns_include
   ,p.rows AS PartitionRows
   ,INDEXPROPERTY(o.object_id, i.name, 'IndexDepth') AS IndexDepth
   ,CONVERT(NUMERIC(19, 3), pst.used_page_count / 128.0) AS SizeMB
   ,i.is_unique
   ,i.is_primary_key
   ,i.is_unique_constraint
   ,SUBSTRING(p.data_compression_desc, 1, 1) AS compression
   ,ISNULL(ius.user_seeks, 0) AS user_seeks
   ,ISNULL(ius.user_scans, 0) AS user_scans
   ,ISNULL(ius.user_lookups, 0) AS user_lookups
   ,ISNULL(ius.user_updates, 0) AS user_updates
   ,iop.leaf_insert_count
   ,iop.leaf_delete_count
   ,iop.leaf_update_count
   ,ISNULL(ius.system_seeks, 0) AS system_seeks
   ,ISNULL(ius.system_scans, 0) AS system_scans
   ,ISNULL(ius.system_lookups, 0) AS system_lookups
   ,ISNULL(ius.system_updates, 0) AS system_updates
   ,pf.name AS PartitionFunction
   ,ds.name AS PartitionScheme
   ,i.index_id
   ,p.partition_number AS PartitionNumber
   ,prv_left.value AS PartitionLowerBoundaryValue
   ,prv_right.value AS PartitionUpperBoundaryValue
   ,CASE WHEN pf.boundary_value_on_right = 1 THEN 'RIGHT'
         WHEN pf.boundary_value_on_right = 0 THEN 'LEFT'
         ELSE 'NONE'
    END AS PartitionRange
   ,i.fill_factor
   ,CASE WHEN i.has_filter = 1 THEN i.filter_definition
         ELSE '-'
    END filter_definition
   ,o.create_date
   ,o.modify_date
   ,o.object_id
   ,ius.last_user_seek
   ,ius.last_user_scan
   ,ius.last_user_lookup
   ,ius.last_user_update
   ,ius.last_system_seek
   ,ius.last_system_scan
   ,ius.last_system_lookup
   ,ius.last_system_update
   ,iop.leaf_ghost_count
   ,iop.nonleaf_insert_count
   ,iop.nonleaf_delete_count
   ,iop.nonleaf_update_count
   ,iop.leaf_allocation_count
   ,iop.nonleaf_allocation_count
   ,iop.leaf_page_merge_count
   ,iop.nonleaf_page_merge_count
   ,iop.range_scan_count
   ,iop.singleton_lookup_count
   ,iop.forwarded_fetch_count
   ,iop.lob_fetch_in_pages
   ,iop.lob_fetch_in_bytes
   ,iop.lob_orphan_create_count
   ,iop.lob_orphan_insert_count
   ,iop.row_overflow_fetch_in_pages
   ,iop.row_overflow_fetch_in_bytes
   ,iop.column_value_push_off_row_count
   ,iop.column_value_pull_in_row_count
   ,iop.row_lock_count
   ,iop.row_lock_wait_count
   ,iop.row_lock_wait_in_ms
   ,iop.page_lock_count
   ,iop.page_lock_wait_count
   ,iop.page_lock_wait_in_ms
   ,iop.index_lock_promotion_attempt_count
   ,iop.index_lock_promotion_count
   ,iop.page_latch_wait_count
   ,iop.page_latch_wait_in_ms
   ,iop.page_io_latch_wait_count
   ,iop.page_io_latch_wait_in_ms
   ,iop.tree_page_latch_wait_count
   ,iop.tree_page_latch_wait_in_ms
   ,iop.tree_page_io_latch_wait_count
   ,iop.tree_page_io_latch_wait_in_ms 
--iop.page_compression_attempt_count ,
--iop.page_compression_success_count
  INTO
    #tmp
  FROM
    sys.partitions AS p
  INNER JOIN sys.indexes AS i
    ON i.object_id = p.object_id
       AND i.index_id = p.index_id
  JOIN 
    sys.dm_db_partition_stats AS pst
    ON i.object_id = pst.object_id
       AND i.index_id = pst.index_id
       AND pst.partition_id = p.partition_id
  INNER JOIN sys.objects AS o
    ON o.object_id = i.object_id
  CROSS APPLY (SELECT
                  LEFT(index_columns_key, LEN(index_columns_key) - 1) AS index_columns_key
                 ,LEFT(index_columns_include, LEN(index_columns_include) - 1) AS index_columns_include
                FROM
                  (SELECT
                      (SELECT
                          sc.name + ' ' + QUOTENAME(st.name) + ', '
                        FROM
                          sys.index_columns scn
                        JOIN 
                          sys.columns sc
                          ON scn.column_id = sc.column_id
                             AND scn.object_id = sc.object_id
                        JOIN 
                          sys.types st
                          ON st.user_type_id = sc.user_type_id
                        WHERE
                          scn.is_included_column = 0
                          AND i.object_id = scn.object_id
                          AND i.index_id = scn.index_id
                        ORDER BY
                          key_ordinal
                      FOR
                       XML PATH('')
                      ) AS index_columns_key
                     ,(SELECT
                          sc.name + ', '
                        FROM
                          sys.index_columns scn
                        JOIN 
                          sys.columns sc
                          ON scn.column_id = sc.column_id
                             AND scn.object_id = sc.object_id
                        WHERE
                          scn.is_included_column = 1
                          AND i.object_id = scn.object_id
                          AND i.index_id = scn.index_id
                        ORDER BY
                          index_column_id
                      FOR
                       XML PATH('')
                      ) AS index_columns_include
                  ) AS Index_Columns
              ) AS Index_Columns
  LEFT JOIN sys.dm_db_index_usage_stats ius
    ON i.index_id = ius.index_id
       AND i.object_id = ius.object_id
       AND ius.database_id = DB_ID()
  LEFT JOIN sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) iop
    ON iop.object_id = o.object_id
       AND iop.index_id = i.index_id
       AND iop.partition_number = pst.partition_number
  LEFT JOIN sys.data_spaces AS ds
    ON ds.data_space_id = i.data_space_id
  LEFT JOIN sys.partition_schemes AS ps
    ON ps.data_space_id = ds.data_space_id
  LEFT JOIN sys.partition_functions AS pf
    ON pf.function_id = ps.function_id
  LEFT JOIN sys.partition_range_values AS prv_left
    ON ps.function_id = prv_left.function_id
       AND prv_left.boundary_id = p.partition_number - 1
  LEFT JOIN sys.partition_range_values AS prv_right
    ON ps.function_id = prv_right.function_id
       AND prv_right.boundary_id = p.partition_number
  WHERE
    o.type IN ('U', 'V');

SELECT *
FROM #tmp
ORDER BY 
   user_scans desc
   