SELECT DWH_TOOLKIT.SQLSharp.String_Join('
SELECT ''KILL '' + CAST(session_ID AS VARCHAR(MAX))  
FROM sys.dm_exec_sessions 
WHERE login_name LIKE ''%pehe''', ';
', 1)

