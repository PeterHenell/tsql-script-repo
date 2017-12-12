
-- Dictionaries per clustered column store index
SELECT OBJECT_NAME(i.object_id) as TableName, count(csd.column_id) as DictionariesCount, 
		cast( SUM(csd.on_disk_size)/(1024.0*1024.0) as Decimal(9,2)) as on_disk_size_MB
    FROM sys.indexes AS i
    JOIN sys.partitions AS p
        ON i.object_id = p.object_id 
    JOIN sys.column_store_dictionaries AS csd
        ON csd.hobt_id = p.hobt_id
    where 1=1 
        AND i.type_desc = 'CLUSTERED COLUMNSTORE'
		AND csd.dictionary_id = 0
	group by OBJECT_NAME(i.object_id);


-- Row groups
select OBJECT_NAME(rg.object_id) as TableName, count(*) as RowGroupsCount, cast(sum(size_in_bytes) / 1024.0 / 1024  as Decimal(9,2)) as SizeInMb
	from sys.column_store_row_groups rg
	where 1=1
	group by OBJECT_NAME(rg.object_id);


-- Segments
SELECT     OBJECT_NAME(i.object_id)          AS TableName,
           i.name                            AS IndexName,
           i.type_desc                       AS IndexType,
           COALESCE(c.name, '* Internal *')  AS ColumnName,
           p.partition_number,
           s.segment_id,
           s.row_count,
           s.on_disk_size,
           s.min_data_id,
           s.max_data_id
FROM       sys.column_store_segments         AS s
INNER JOIN sys.partitions                    AS p 
      ON   p.hobt_id                          = s.hobt_id
INNER JOIN sys.indexes                       AS i 
      ON   i.object_id                        = p.object_id
      AND  i.index_id                         = p.index_id
LEFT  JOIN sys.index_columns                 AS ic
      ON   ic.object_id                       = i.object_id
      AND  ic.index_id                        = i.index_id
      AND  ic.index_column_id                 = s.column_id
LEFT  JOIN sys.columns                       AS c
      ON   c.object_id                        = ic.object_id
      AND  c.column_id                        = ic.column_id
WHERE      i.name                            IN (N'NCI_FactOnlineSales',
                                                 N'CCI_FactOnlineSales2')
ORDER BY   TableName, IndexName,
           s.column_id, p.partition_number, s.segment_id;


-- Dicitonary information
SELECT     OBJECT_NAME(i.object_id)          AS TableName,
           i.name                            AS IndexName,
           i.type_desc                       AS IndexType,
           COALESCE(c.name, '* Internal *')  AS ColumnName,
           p.partition_number,
           s.segment_id,
           s.encoding_type,
           dG.type                           AS GlDictType,
           dG.entry_count                    AS GlDictEntryCount,
           dG.on_disk_size                   AS GlDictOnDiskSize,
           dL.type                           AS LcDictType,
           dL.entry_count                    AS LcDictEntryCount,
           dL.on_disk_size                   AS LcDictOnDiskSize
FROM       sys.column_store_segments         AS s
INNER JOIN sys.partitions                    AS p 
      ON   p.hobt_id                          = s.hobt_id
INNER JOIN sys.indexes                       AS i 
      ON   i.object_id                        = p.object_id
      AND  i.index_id                         = p.index_id
LEFT  JOIN sys.index_columns                 AS ic
      ON   ic.object_id                       = i.object_id
      AND  ic.index_id                        = i.index_id
      AND  ic.index_column_id                 = s.column_id
LEFT  JOIN sys.columns                       AS c
      ON   c.object_id                        = ic.object_id
      AND  c.column_id                        = ic.column_id
LEFT  JOIN sys.column_store_dictionaries     AS dG         -- Global dictionary
      ON   dG.hobt_id                         = s.hobt_id
      AND  dG.column_id                       = s.column_id
      AND  dG.dictionary_id                   = s.primary_dictionary_id
LEFT  JOIN sys.column_store_dictionaries     AS dL         -- Local dictionary
      ON   dL.hobt_id                         = s.hobt_id
      AND  dL.column_id                       = s.column_id
      AND  dL.dictionary_id                   = s.secondary_dictionary_id
WHERE      i.name                            IN (N'NCI_FactOnlineSales',
                                                 N'CCI_FactOnlineSales2')
AND        s.encoding_type                   IN (2, 3)
ORDER BY   TableName, IndexName,
           s.column_id, p.partition_number, s.segment_id;

-- Check the locks that are taken
-- (Query adapted from http://www.nikoport.com/2013/07/07/clustered-columnstore-indexes-part-8-locking/)
SELECT l.request_session_id,
       DB_NAME(l.resource_database_id) AS database_name,
       CASE
           WHEN l.resource_type = 'OBJECT' THEN
               OBJECT_NAME(l.resource_associated_entity_id)
           ELSE
               OBJECT_NAME(p.[object_id])
       END AS [object_name],
       i.name AS index_name,
       l.resource_type,
       l.resource_description,
       l.request_mode,
       l.request_status
FROM sys.dm_tran_locks AS l
    INNER JOIN sys.partitions AS p
        ON p.hobt_id = l.resource_associated_entity_id
    INNER JOIN sys.indexes AS i
        ON i.[object_id] = p.[object_id]
           AND i.index_id = p.index_id
WHERE l.resource_associated_entity_id > 0
      AND l.resource_database_id = DB_ID()
ORDER BY l.request_session_id,
         resource_associated_entity_id;


-- Distribution of values per rowgroup and column 
-- This information is useful for identifying how good rowgroup elimination we can expect per column
-- Note: Example table used, need to replace columns with actual columns
SELECT     p.partition_number, 
           s.segment_id,
           MAX(s.row_count) AS row_count,
           MAX(CASE WHEN c.name = N'OnlineSalesKey' 
                    THEN s.min_data_id END) AS MinOnlineSalesKey,
           MAX(CASE WHEN c.name = N'OnlineSalesKey' 
                    THEN s.max_data_id END) AS MaxOnlineSalesKey,
           MAX(CASE WHEN c.name = N'StoreKey'       
                    THEN s.min_data_id END) AS MinStoreKey,
           MAX(CASE WHEN c.name = N'StoreKey'       
                    THEN s.max_data_id END) AS MaxStoreKey,
           MAX(CASE WHEN c.name = N'ProductKey'     
                    THEN s.min_data_id END) AS MinProductKey,
           MAX(CASE WHEN c.name = N'ProductKey'     
                    THEN s.max_data_id END) AS MaxProductKey
FROM       sys.column_store_segments        AS s
INNER JOIN sys.partitions                   AS p 
      ON   p.hobt_id                         = s.hobt_id
INNER JOIN sys.indexes                      AS i 
      ON   i.object_id                       = p.object_id
      AND  i.index_id                        = p.index_id
LEFT  JOIN sys.index_columns                AS ic
      ON   ic.object_id                      = i.object_id
      AND  ic.index_id                       = i.index_id
      AND  ic.index_column_id                = s.column_id
LEFT  JOIN sys.columns                      AS c
      ON   c.object_id                       = ic.object_id
      AND  c.column_id                       = ic.column_id
WHERE      i.name                            = N'CCI_FactOnlineSales2'
AND        c.name IN (N'OnlineSalesKey', N'StoreKey', N'ProductKey')
GROUP BY   p.partition_number,
           s.segment_id;


-- Descriptions 
SELECT object_id,
       index_id,
       partition_number,
       row_group_id, -- The row group number associated with this row group. This is unique within the partition.
                     -- -1 = tail of an in-memory table.
       
       delta_store_hobt_id, -- The hobt_id for OPEN row group in the delta store.
                            -- NULL if the row group is not in the delta store.
                            -- NULL for the tail of an in-memory table.
       state,           -- ID number associated with the state_description.
                        -- 0 = INVISIBLE
                        -- 1 = OPEN
                        -- 2 = CLOSED
                        -- 3 = COMPRESSED 
                        -- 4 = TOMBSTONE

       state_description,   -- Description of the persistent state of the row group:
                            -- INVISIBLE –A hidden compressed segment in the process of being built from data in a delta store. Read actions will use the delta store until the invisible compressed segment is completed. Then the new segment is made visible, and the source delta store is removed.
                            -- OPEN – A read/write row group that is accepting new records. An open row group is still in rowstore format and has not been compressed to columnstore format.
                            -- CLOSED – A row group that has been filled, but not yet compressed by the tuple mover process.
                            -- COMPRESSED – A row group that has filled and compressed.

       total_rows,      -- Total rows physically stored in the row group. Some may have been deleted but they are still stored. The maximum number of rows in a row group is 1,048,576 (hexadecimal FFFFF).
       deleted_rows,    -- Total rows in the row group marked deleted. This is always 0 for DELTA row groups.
       size_in_bytes    -- Size in bytes of all the data in this row group (not including metadata or shared dictionaries), for both DELTA and COLUMNSTORE rowgroups.

FROM sys.column_store_row_groups