-- http://weblogs.sqlteam.com/mladenp/archive/2010/10/12/sql-server-ndash-undelete-a-table-and-restore-a-single.aspx
USE master
GO
-- http://sqlblog.com/blogs/peter_debetta/archive/2007/03/09/t-sql-convert-hex-string-to-varbinary.aspx
CREATE FUNCTION dbo.HexStrToVarBin(@hexstr VARCHAR(8000))  
RETURNS varbinary(8000)  
AS  
BEGIN  
   DECLARE @hex CHAR(2), @i INT, @count INT, @b varbinary(8000), @odd BIT, @start bit 
   SET @count = LEN(@hexstr)  
   SET @start = 1 
   SET @b = CAST('' AS varbinary(1))  
   IF SUBSTRING(@hexstr, 1, 2) = '0x'  
       SET @i = 3  
   ELSE  
       SET @i = 1  
   SET @odd = CAST(LEN(SUBSTRING(@hexstr, @i, LEN(@hexstr))) % 2 AS BIT) 
   WHILE (@i <= @count)  
    BEGIN  
       IF @start = 1 AND @odd = 1 
       BEGIN 
           SET @hex = '0' + SUBSTRING(@hexstr, @i, 1) 
       END 
       ELSE 
       BEGIN 
           SET @hex = SUBSTRING(@hexstr, @i, 2) 
       END 
       SET @b = @b +  
               CAST(CASE WHEN SUBSTRING(@hex, 1, 1) LIKE '[0-9]'  
                   THEN CAST(SUBSTRING(@hex, 1, 1) AS INT)  
                   ELSE CAST(ASCII(UPPER(SUBSTRING(@hex, 1, 1)))-55 AS INT)  
               END * 16 +  
               CASE WHEN SUBSTRING(@hex, 2, 1) LIKE '[0-9]'  
                   THEN CAST(SUBSTRING(@hex, 2, 1) AS INT)  
                   ELSE CAST(ASCII(UPPER(SUBSTRING(@hex, 2, 1)))-55 AS INT)  
               END AS binary(1))  
       SET @i = @i + (2 - (CAST(@start AS INT) * CAST(@odd AS INT))) 
       IF @start = 1 
       BEGIN 
           SET @start = 0 
       END 
    END  
    RETURN @b  
END  
GO  
GO
IF OBJECT_ID('dbo.HexStrToVarBin') IS NULL
    RAISERROR ('No dbo.HexStrToVarBin installed. 
Go to http://sqlblog.com/blogs/peter_debetta/archive/2007/03/09/t-sql-convert-hex-string-to-varbinary.aspx 
and install it in master database' , 18, 1)    
SET NOCOUNT ON
BEGIN TRY    
    DECLARE @dbName VARCHAR(1000), @schemaName VARCHAR(1000), @tableName VARCHAR(1000),
            @fullBackupName VARCHAR(1000), @undeletedTableName VARCHAR(1000),
            @sql VARCHAR(MAX), @tableWasTruncated bit;
    /*
    THE FIRST LINE ARE OUR INPUT PARAMETERS 
    In this case we're trying to recover Production.Product1 table in AdventureWorks database.
    My full backup of AdventureWorks database is at e:\AW.bak
    */
    SELECT  @dbName = 'AdventureWorks', @schemaName = 'Production', @tableName = 'Product1', @fullBackupName = 'e:\AW.bak', 
            @undeletedTableName = '##' + @tableName + '_Undeleted', @tableWasTruncated = 0,
            -- copy the structure from original table to a temp table that we'll fill with restored data
            @sql = 'IF OBJECT_ID(''tempdb..' + @undeletedTableName + 
                                 ''') IS NOT NULL DROP TABLE ' + @undeletedTableName +
                   ' SELECT *' +
                   ' INTO ' + @undeletedTableName +
                   ' FROM [' + @dbName + '].[' + @schemaName + '].[' + @tableName + ']' +
                   ' WHERE 1 = 0'
    EXEC (@sql)
    IF OBJECT_ID('tempdb..#PagesToRestore') IS NOT NULL 
        DROP TABLE #PagesToRestore        
    /* FIND DATA PAGES WE NEED TO RESTORE*/
    CREATE TABLE #PagesToRestore ([ID] INT IDENTITY(1,1), [FileID] INT, [PageID] INT, 
                                    [SQLtoExec] VARCHAR(1000)) -- DBCC PACE statement to run later
    RAISERROR ('Looking for deleted pages...', 10, 1)    
    -- use T-LOG direct read to get deleted data pages
    INSERT INTO #PagesToRestore([FileID], [PageID], [SQLtoExec])
    EXEC('USE [' + @dbName + '];SELECT  FileID, PageID, ''DBCC TRACEON (3604); DBCC PAGE ([' + @dbName + 
            '], '' + FileID + '', '' + PageID + '', 3) WITH TABLERESULTS'' as SQLToExec
FROM (SELECT DISTINCT LEFT([Page ID], 4) AS FileID, CONVERT(VARCHAR(100), ' + 
             'CONVERT(INT, master.dbo.HexStrToVarBin(SUBSTRING([Page ID], 6, 20)))) AS PageID
FROM    sys.fn_dblog(NULL, NULL)
WHERE    AllocUnitName LIKE ''%' + @schemaName  + '.' + @tableName + '%'' ' +
       'AND Context IN (''LCX_MARK_AS_GHOST'', ''LCX_HEAP'') AND Operation in (''LOP_DELETE_ROWS''))t');
SELECT  *
FROM    #PagesToRestore
    -- if upper EXEC returns 0 rows it means the table was truncated so find truncated pages
    IF (SELECT COUNT(*) FROM #PagesToRestore) = 0
    BEGIN
        RAISERROR ('No deleted pages found. Looking for truncated pages...', 10, 1)    
        -- use T-LOG read to get truncated data pages
        INSERT INTO #PagesToRestore([FileID], [PageID], [SQLtoExec])
        -- dark magic happens here
        -- because truncation simply deallocates pages we have to find out which pages were deallocated.
        -- we can find this out by looking at the PFS page row's Description column.
        -- for every deallocated extent the Description has a CSV of 8 pages in that extent.
        -- then it's just a matter of parsing it.
        -- we also remove the pages in the extent that weren't allocated to the table itself 
        -- marked with '0x00-->00'
        EXEC ('USE [' + @dbName + '];DECLARE @truncatedPages TABLE(DeallocatedPages VARCHAR(8000), IsMultipleDeallocs BIT);
INSERT INTO @truncatedPages
SELECT  REPLACE(REPLACE(Description, ''Deallocated '', ''Y''), ''0x00-->00 '', ''N'') + '';'' AS DeallocatedPages,
        CHARINDEX('';'', Description) AS IsMultipleDeallocs
FROM    (
SELECT  DISTINCT LEFT([Page ID], 4) AS FileID, CONVERT(VARCHAR(100), 
        CONVERT(INT, master.dbo.HexStrToVarBin(SUBSTRING([Page ID], 6, 20)))) AS PageID, 
        Description
FROM    sys.fn_dblog(NULL, NULL)
WHERE    Context IN (''LCX_PFS'') AND Description LIKE ''Deallocated%''
        AND AllocUnitName LIKE ''%' + @schemaName  + '.' + @tableName + '%'') t;
SELECT  FileID, PageID 
        , ''DBCC TRACEON (3604); DBCC PAGE ([' + @dbName + '], '' + FileID + '', '' + PageID + '', 3) WITH TABLERESULTS'' as SQLToExec
FROM    (
SELECT  LEFT(PageAndFile, 1) as WasPageAllocatedToTable
        , SUBSTRING(PageAndFile, 2, CHARINDEX('':'', PageAndFile) - 2 ) as FileID
        , CONVERT(VARCHAR(100), CONVERT(INT, 
                    master.dbo.HexStrToVarBin(SUBSTRING(PageAndFile, CHARINDEX('':'', PageAndFile) + 1, LEN(PageAndFile))))) as PageID
FROM    (
        SELECT  SUBSTRING(DeallocatedPages, delimPosStart, delimPosEnd - delimPosStart) as PageAndFile, IsMultipleDeallocs
        FROM    (
                SELECT  *,        
                        CHARINDEX('';'', DeallocatedPages)*(N-1) + 1 AS delimPosStart,
                        CHARINDEX('';'', DeallocatedPages)*N         
                        AS delimPosEnd
                FROM    @truncatedPages t1
                        CROSS APPLY 
                        (SELECT TOP (case when t1.IsMultipleDeallocs = 1 then 8 else 1 end) 
                                ROW_NUMBER() OVER(ORDER BY number) as N 
                        FROM master..spt_values) t2
                )t)t)t
WHERE WasPageAllocatedToTable = ''Y''')
        SELECT @tableWasTruncated = 1
    END    
    DECLARE @lastID INT, @pagesCount INT
    SELECT @lastID = 1, @pagesCount = COUNT(*) FROM #PagesToRestore
    SELECT @sql = 'Number of pages to restore: ' + CONVERT(VARCHAR(10), @pagesCount)
    IF @pagesCount = 0
        RAISERROR ('No data pages to restore.', 18, 1)    
    ELSE
        RAISERROR (@sql, 10, 1)    
    -- If the table was truncated we'll read the data directly from data pages without restoring from backup
    IF @tableWasTruncated = 0
    BEGIN 
        -- RESTORE DATA PAGES FROM FULL BACKUP IN BATCHES OF 200
        WHILE @lastID <= @pagesCount 
        BEGIN
            -- create CSV string of pages to restore
            SELECT @sql = STUFF((SELECT ',' + CONVERT(VARCHAR(100), FileID) + ':' + CONVERT(VARCHAR(100), PageID)
                                 FROM #PagesToRestore WHERE ID BETWEEN @lastID AND @lastID + 200
                                 ORDER BY ID FOR XML PATH('')), 1, 1, '')    
            SELECT @sql = 'RESTORE DATABASE [' + @dbName + '] PAGE = ''' + @sql + ''' FROM DISK = ''' + @fullBackupName + ''''
            RAISERROR ('Starting RESTORE command:' , 10, 1) WITH NOWAIT;
            RAISERROR (@sql , 10, 1) WITH NOWAIT;
            EXEC(@sql);
            RAISERROR ('Restore DONE' , 10, 1) WITH NOWAIT;
            SELECT @lastID = @lastID + 200
        END    
        /*
            If you have any differential or transaction log backups you 
            should restore them here to bring the previously restored data pages up to date        
        */
    END    
    DECLARE @dbccSinglePage TABLE 
    (
        [ParentObject] NVARCHAR(500), 
        [Object] NVARCHAR(500), 
        [Field] NVARCHAR(500), 
        [VALUE] NVARCHAR(MAX)
    )
    DECLARE @cols NVARCHAR(MAX), @paramDefinition NVARCHAR(500), @SQLtoExec VARCHAR(1000),
            @FileID VARCHAR(100), @PageID VARCHAR(100), @i INT = 1
    -- Get deleted table columns from information_schema view
    -- Need sp_executeSQL because database name can't be passed in as variable
    SELECT @cols = 'select @cols = STUFF((SELECT '', ['' + COLUMN_NAME + '']''
FROM   ' + @dbName + '.INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_NAME = ''' + @tableName + ''' AND
       TABLE_SCHEMA = ''' + @schemaName + '''
ORDER BY ORDINAL_POSITION
FOR XML PATH('''')), 1, 2, '''')', @paramDefinition = N'@cols nvarchar(max) OUTPUT'
    EXECUTE sp_executesql @cols, @paramDefinition, @cols = @cols OUTPUT    
    -- Loop through all the restored data pages,
    -- read data from them and insert them into temp table
    -- which you can then insert into the orignial deleted table
    DECLARE dbccPageCursor CURSOR GLOBAL FORWARD_ONLY FOR     
    SELECT [FileID], [PageID], [SQLtoExec] FROM #PagesToRestore ORDER BY [FileID], [PageID]            
    OPEN dbccPageCursor;
    FETCH NEXT FROM dbccPageCursor INTO @FileID, @PageID, @SQLtoExec;
    WHILE @@FETCH_STATUS = 0    
    BEGIN
        RAISERROR ('---------------------------------------------', 10, 1) WITH NOWAIT;
        SELECT @sql = 'Loop iteration: ' + CONVERT(VARCHAR(10), @i);
        RAISERROR (@sql, 10, 1) WITH NOWAIT;
        
        SELECT @sql = 'Running: ' + @SQLtoExec
        RAISERROR (@sql, 10, 1) WITH NOWAIT;         
        
        -- if something goes wrong with DBCC execution or data gathering, skip it but print error
        BEGIN TRY
            INSERT INTO @dbccSinglePage EXEC (@SQLtoExec)
            
            -- make the data insert magic happen here
            IF (SELECT CONVERT(BIGINT, [VALUE]) FROM @dbccSinglePage WHERE [Field] LIKE '%Metadata: ObjectId%') 
                = OBJECT_ID('['+@dbName+'].['+@schemaName +'].['+@tableName+']')
            BEGIN            
                DELETE    @dbccSinglePage
                WHERE    NOT ([ParentObject] LIKE 'Slot % Offset %' AND [Object] LIKE 'Slot % Column %')
                
                SELECT @sql = 'USE tempdb; ' +
                              'IF (OBJECTPROPERTY(object_id(''' + @undeletedTableName + '''), ''TableHasIdentity'') = 1) ' +
                              'SET IDENTITY_INSERT ' + @undeletedTableName + ' ON; ' +
                              'INSERT INTO ' + @undeletedTableName + 
                              '(' + @cols + ') ' + 
                              STUFF((SELECT    ' UNION ALL SELECT ' + 
                                      STUFF((SELECT ', ' + CASE WHEN VALUE = '[NULL]' THEN 'NULL' ELSE '''' + [VALUE] + '''' END
                                             FROM (
                                              -- the unicorn help here to correctly set ordinal numbers of columns in a data page
                                              -- it's turning STRING order into INT order (1,10,11,2,21 into 1,2,..10,11...21)
                                                  SELECT [ParentObject], [Object], Field, VALUE,
                                                         RIGHT('00000' + O1, 6) AS ParentObjectOrder,
                                                         RIGHT('00000' + REVERSE(LEFT(O2, CHARINDEX(' ', O2)-1)), 6) AS ObjectOrder
                                                  FROM   (
                                                         SELECT  [ParentObject], [Object], Field, VALUE,
                                                                 REPLACE(LEFT([ParentObject], 
                                                                              CHARINDEX('Offset', [ParentObject])-1), 
                                                                         'Slot ', '') AS O1,
                                                                 REVERSE(LEFT([Object], 
                                                                              CHARINDEX('Offset ', [Object])-2)) AS O2
                                                          FROM   @dbccSinglePage
                                                          WHERE  t.ParentObject = ParentObject )t)t
                                                          ORDER BY ParentObjectOrder, ObjectOrder
                                                          FOR XML PATH('')), 1, 2, '')
                                                  FROM    @dbccSinglePage t
                                                  GROUP BY ParentObject
                                                  FOR XML PATH('')
                                    ), 1, 11, '') + ';'
                RAISERROR (@sql, 10, 1) WITH NOWAIT;
                EXEC (@sql)
            END            
        END TRY
        BEGIN CATCH
            SELECT    @sql = 'ERROR!!!' + CHAR(10) + CHAR(13) + 
                           'ErrorNumber: ' + ERROR_NUMBER() + '; ErrorMessage' + ERROR_MESSAGE() + 
                           CHAR(10) + CHAR(13) + 'FileID: ' + @FileID + '; PageID: ' + @PageID
            RAISERROR (@sql, 10, 1) WITH NOWAIT;
        END CATCH        
        DELETE @dbccSinglePage
        SELECT    @sql = 'Pages left to process: ' + CONVERT(VARCHAR(10), @pagesCount - @i) + 
                        CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13), @i = @i+1    
        RAISERROR (@sql, 10, 1) WITH NOWAIT;
        FETCH NEXT FROM dbccPageCursor INTO @FileID, @PageID, @SQLtoExec;
    END
    CLOSE dbccPageCursor; DEALLOCATE dbccPageCursor;
    EXEC ('SELECT ''' + @undeletedTableName + ''' as TableName; SELECT * FROM ' + @undeletedTableName)
END TRY
BEGIN CATCH        
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage
    IF CURSOR_STATUS ('global', 'dbccPageCursor') >= 0
    BEGIN 
        CLOSE dbccPageCursor;
        DEALLOCATE dbccPageCursor;
    END
END CATCH

-- if the table was deleted we need to finish the restore page sequence
IF @tableWasTruncated = 0
BEGIN
    -- take a log tail backup and then restore it to complete page restore process 
    DECLARE @currentDate VARCHAR(30)
    SELECT @currentDate = CONVERT(VARCHAR(30), GETDATE(), 112)

    RAISERROR ('Starting Log Tail backup to c:\Temp ...', 10, 1) WITH NOWAIT;
    PRINT ('BACKUP LOG [' + @dbName + '] TO DISK = ''c:\Temp\' + @dbName + '_TailLogBackup_' + @currentDate + '.trn''')
    EXEC ('BACKUP LOG [' + @dbName + '] TO DISK = ''c:\Temp\' + @dbName + '_TailLogBackup_' + @currentDate + '.trn''')    
    RAISERROR ('Log Tail backup done.', 10, 1) WITH NOWAIT;

    RAISERROR ('Starting Log Tail restore from c:\Temp ...', 10, 1) WITH NOWAIT;
    PRINT ('RESTORE LOG [' + @dbName + '] FROM DISK = ''c:\Temp\' + @dbName + '_TailLogBackup_' + @currentDate + '.trn''')
    EXEC ('RESTORE LOG [' + @dbName + '] FROM DISK = ''c:\Temp\' + @dbName + '_TailLogBackup_' + @currentDate + '.trn''')    
    RAISERROR ('Log Tail restore done.', 10, 1) WITH NOWAIT;
END
