IF OBJECT_ID('tempdb..#RowCountsAndSizes') IS NOT NULL DROP TABLE #RowCountsAndSizes;

CREATE TABLE #RowCountsAndSizes (TableName NVARCHAR(128),rows CHAR(11),      
       reserved VARCHAR(18),data VARCHAR(18),index_size VARCHAR(18), 
       unused VARCHAR(18));

EXEC       sp_MSForEachTable 'INSERT INTO #RowCountsAndSizes EXEC sp_spaceused ''?'' ';

SELECT     TableName,CONVERT(bigint,rows) AS NumberOfRows,
           CONVERT(bigint,left(reserved,len(reserved)-3)) AS SizeinKB
FROM       #RowCountsAndSizes 
ORDER BY   NumberOfRows DESC,SizeinKB DESC,TableName


SELECT  
    SchemaName = SCHEMA_NAME(t.schema_id),
    TableName = t.name,
    NumberOfRows = i.rows
FROM       sys.tables t
INNER JOIN sys.sysindexes i
    ON t.object_id = i.id
WHERE indid IN (0,1)
    AND SCHEMA_NAME(t.schema_id) = 'NetSuite_RawTyped'
ORDER BY
    SCHEMA_NAME(t.schema_id), 
    t.name
    

--DROP TABLE #RowCountsAndSizes