IF OBJECT_ID('TempDB..#columnStats') IS NOT NULL DROP TABLE #columnStats;
IF OBJECT_ID('TempDB..#currVsPrev') IS NOT NULL DROP TABLE #currVsPrev;

CREATE TABLE #columnStats (
	[RANGE_HI_KEY]	DECIMAL(30,6),
	[RANGE_ROWS]	REAL,
	[EQ_ROWS]	REAL,
	[DISTINCT_RANGE_ROWS]	BIGINT,
	[AVG_RANGE_ROWS]	REAL
);
INSERT INTO #columnStats
EXEC('DBCC SHOW_STATISTICS ([dwh.creditQualityValues],expectedLossFactor) WITH NO_INFOMSGS, Histogram')
;
--SELECT
-- [RANGE_HI_KEY],
-- [RANGE_ROWS],
-- [EQ_ROWS],
-- [DISTINCT_RANGE_ROWS],
-- [AVG_RANGE_ROWS],
-- prevRow = LAG(RANGE_HI_KEY, 1) OVER (ORDER BY RANGE_HI_KEY)

--FROM #columnStats
--ORDER BY RANGE_HI_KEY;




WITH numbered AS (
    SELECT rn = ROW_NUMBER() OVER (ORDER BY range_Hi_Key), *
    FROM #columnStats
)
SELECT [Curr_rn] = curr.rn ,
       [Curr_RANGE_HI_KEY] = curr.RANGE_HI_KEY ,
       [Curr_RANGE_ROWS] = curr.RANGE_ROWS ,
       [Curr_EQ_ROWS] = curr.EQ_ROWS ,
       [Curr_DISTINCT_RANGE_ROWS] = curr.DISTINCT_RANGE_ROWS ,
       [Curr_AVG_RANGE_ROWS] = curr.AVG_RANGE_ROWS, 
       
       [Prev_rn] = prev.rn ,
       [Prev_RANGE_HI_KEY] = prev.RANGE_HI_KEY ,
       [Prev_RANGE_ROWS] = prev.RANGE_ROWS ,
       [Prev_EQ_ROWS] = prev.EQ_ROWS ,
       [Prev_DISTINCT_RANGE_ROWS] = prev.DISTINCT_RANGE_ROWS ,
       [Prev_AVG_RANGE_ROWS]= prev.AVG_RANGE_ROWS
INTO #currVsPrev
FROM numbered curr
OUTER APPLY (SELECT * FROM numbered prev WHERE prev.rn = curr.rn - 1) prev

--SELECT * FROM #currVsPrev

SELECT COUNT(*), expectedLossFactor 
FROM dwh.creditQualityValues
OUTER APPLY(SELECT Prev_RANGE_HI_KEY, Curr_RANGE_HI_KEY, Prev_EQ_ROWS, Prev_RANGE_ROWS
             FROM #currVsPrev 
             WHERE expectedLossFactor >= Prev_RANGE_HI_KEY AND expectedLossFactor < Curr_RANGE_HI_KEY) statvalue
WHERE statvalue.Prev_RANGE_HI_KEY IS NULL
      AND expectedLossFactor IS NOT NULL
GROUP BY expectedLossFactor
;