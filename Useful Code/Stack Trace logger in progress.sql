DECLARE @PROCID INT = @@PROCID; -- the ID of the procedure to  

DECLARE @BIN VARBINARY(128) 
SELECT @BIN = CONVERT(BINARY(4), @PROCID) + ISNULL(CONTEXT_INFO(), CAST('' AS VARBINARY(1))) 
SET CONTEXT_INFO @BIN 

GO
DECLARE @BIN VARBINARY(128) 
SELECT @BIN = ISNULL(CONTEXT_INFO(), CAST('' AS VARBINARY(1))) 
SELECT @BIN = SUBSTRING(@BIN, 5, 128) 
  
SET CONTEXT_INFO @BIN 

GO
DECLARE @result TABLE ( 
    SchemaId INT, 
    SchemaName VARCHAR(256), 
    ProcedureId INT, 
    ProcedureName VARCHAR(256) 
) 
    DECLARE @BIN VARBINARY(128) 
    SELECT @BIN = ISNULL(CONTEXT_INFO(), CAST('' AS VARBINARY(1))) 
  
    DECLARE @PROCID INT 
  
    WHILE (LEN(@BIN) > 0 AND CONVERT(INT, SUBSTRING(@BIN, 1, 4)) > 0) BEGIN 
        SET @PROCID = CONVERT(INT, SUBSTRING(@BIN, 1, 4)) 
        SET @BIN = SUBSTRING(@BIN, 5, 128) 
  
        INSERT @result ( 
            SchemaId, 
            SchemaName, 
            ProcedureId, 
            ProcedureName 
        ) 
        SELECT 
            s.schema_id, 
            s.name, 
            o.object_id, 
            o.name 
        FROM sys.objects o 
        INNER JOIN sys.schemas s ON s.schema_id = o.schema_id 
        WHERE o.object_id = @PROCID 
    END 


CREATE TABLE #inp_buff ( 
    EventType NVARCHAR(30), 
    Parameters INT, 
    EventInfo NVARCHAR(255) 
) 
  
INSERT INTO #inp_buff 
EXEC('DBCC INPUTBUFFER(@@SPID) WITH NO_INFOMSGS') 
  
SELECT 
    EventInfo 
FROM #inp_buff 
  
DROP TABLE #inp_buff 