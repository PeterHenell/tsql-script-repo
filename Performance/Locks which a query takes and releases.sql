CREATE TABLE numbers (n BIGINT PRIMARY KEY CLUSTERED);

WITH c3(n) AS (SELECT 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
c2 AS (SELECT n FROM c3 a CROSS JOIN c3 b ON 1=1)
SELECT * FROM c2

INSERT INTO dbo.numbers
        ( n )
SELECT n FROM c1;

TRUNCATE TABLE dbo.peter;
GO
DBCC TRACEON(1200,-1,3604);

DECLARE @dummy VARBINARY(500);

SELECT 
	@dummy = CHECKSUM(*)
FROM 
	dbo.peter WITH(UPDLOCK, ROWLOCK);
	--WHERE 
--	JoinDate = '2012-10-23 18:23:36.0790000';

INSERT INTO peter WITH(TABLOCK)
SELECT TOP 10 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM master..spt_values a WITH(TABLOCK)

--SELECT number FROM master..spt_values

DBCC TRACEOFF(1200,-1,3604);

RETURN;
-- Results, removed the releasing of the locks
--Process 238 acquiring IX lock on OBJECT: 23:1618104805:0  (class bit2000000 ref1) result: OK
--Process 238 acquiring IU lock on PAGE: 23:3:34712  (class bit2000000 ref0) result: OK
--Process 238 acquiring U lock on KEY: 23:72057594055229440 (1d67b5278f3f) (class bit2000000 ref1) result: OK
--Process 238 acquiring IU lock on PAGE: 23:3:30496  (class bit2000000 ref1) result: OK
--Process 238 acquiring U lock on KEY: 23:72057594055098368 (a6e4d014ad5d) (class bit2000000 ref1) result: OK



-- Use this query to see which indexes the query took locks on
SELECT 
		OBJECT_NAME(pt.object_id), 
		i.name,	 
		partition_id ,
        pt.object_id ,
        pt.index_id ,
        partition_number 
        
FROM sys.dm_db_partition_stats pt
LEFT OUTER JOIN sys.indexes i 
	ON 	i.object_id = pt.object_id 
	AND i.index_id = pt.index_id
WHERE 
	partition_id IN( 281474978938880);



-- Inspect the page that was locked if needed
DBCC TRACEON(3604)
DBCC PAGE (23, 3, 34712, 0);
DBCC TRACEOFF(3604)
