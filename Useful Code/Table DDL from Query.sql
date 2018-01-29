SET NOCOUNT ON;

DECLARE @sql NVARCHAR(MAX);
DECLARE @targetTableName NVARCHAR(200) = '#temp';
SET @sql = N'msdb.dbo.sp_help_job @execution_status = 1';


WITH cols(list) AS (
 SELECT 
    ',' + CONCAT(
        name, ' ', system_type_name,
        CASE is_nullable WHEN 0 THEN ' not null' ELSE '' END
    ) AS [text()]
FROM sys.dm_exec_describe_first_result_set(@sql, NULL, 0) AS f
FOR XML PATH('')   
)

SELECT 'CREATE TABLE ' + @targetTableName + '( ' + STUFF(cols.list, 1, 1, '')
FROM cols



--SELECT ');';