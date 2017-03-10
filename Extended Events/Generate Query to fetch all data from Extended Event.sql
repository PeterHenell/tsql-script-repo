	declare @SessionName sysname = 'LockEscalations';

	SET NOCOUNT ON;
	DECLARE @SQL NVARCHAR(MAX);
	DECLARE @tmp table (cmd NVARCHAR(max),rn INT IDENTITY PRIMARY KEY CLUSTERED);
	DECLARE @cols table (colSQL NVARCHAR(max),colname sysname,DataType nvarchar(128),rn INT IDENTITY PRIMARY KEY CLUSTERED);

WITH 
XETypeToSQLType AS (
    SELECT 
        XETypeName = mv.name, 
        SQLTypeName = 'nvarchar('+CAST(MAX(LEN(mv.map_value))-(MAX(LEN(mv.map_value))%10) + 10 AS VARCHAR(4))+')',
        XMLLocation = 'text',
        TypePrecidence = 5
    FROM sys.dm_xe_object_columns oc
    LEFT JOIN sys.dm_xe_map_values mv
        ON oc.type_package_guid = mv.object_package_guid
            AND oc.type_name = mv.name
    WHERE oc.column_type = 'data'
      AND mv.name IS NOT NULL
    GROUP BY mv.name
UNION ALL
    SELECT 
        XETypeName = o.name,
        SQLTypeName = CASE 
                            WHEN TYPE_NAME IN ('int8', 'int16', 'int32', 'uint8', 
                                    'uint16', 'float32') 
                                THEN 'int'
                            WHEN TYPE_NAME IN ('int64', 'float64', 'uint32')
                                THEN 'bigint'
                            WHEN TYPE_NAME = 'boolean'
                                THEN 'nvarchar(10)' --true/false returned
                            WHEN TYPE_NAME = 'guid'
                                THEN 'uniqueidentifier'
                            ELSE 'nvarchar(4000)' -- , 'uint64' is too big for bigint
                        END,
        XMLLocation = 'value',
        TypePrecidence = CASE 
                            WHEN TYPE_NAME IN ('int8', 'int16', 'int32', 'uint8', 
                                    'uint16', 'float32') 
                                THEN 1
                            WHEN TYPE_NAME IN ('int64', 'uint64', 'float64', 'uint32')
                                THEN 2
                            WHEN TYPE_NAME = 'boolean'
                                THEN 3 --true/false returned
                            WHEN TYPE_NAME = 'guid'
                                THEN 3
                            ELSE 5
                         END
    FROM sys.dm_xe_objects o
    WHERE object_type = 'type'
      AND TYPE_NAME != 'null'
	),
XESession_OutputsFromDMVs  AS (
        -- Find a list of all the possible output columns
        SELECT 
            ses.name AS EventSessionName,
            sese.name AS EventName,
            sese.event_id AS EventID,
            oc.column_id AS ColumnID,
            oc.name AS ColumnName,
            'data' AS NodeType,
            xetst.SQLTypeName AS DataType,
            xetst.XMLLocation,
            xetst.TypePrecidence
        FROM sys.server_event_sessions AS ses
        JOIN sys.server_event_session_events AS sese
            ON ses.event_session_id = sese.event_session_id
        JOIN sys.dm_xe_packages AS p 
            ON sese.package = p.name
        JOIN sys.dm_xe_object_columns AS oc 
            ON oc.object_name = sese.name
                AND oc.object_package_guid = p.guid
        JOIN XETypeToSQLType  AS xetst
            ON oc.type_name = xetst.XETypeName
        WHERE oc.column_type = 'data'
    UNION
        SELECT 
            ses.name,
            sese.name,
            sesa.event_id,
            999 AS column_id,
            sesa.name,
            'action',
            xetst.SQLTypeName,
            xetst.XMLLocation,
            xetst.TypePrecidence
        FROM sys.server_event_sessions AS ses
        JOIN sys.server_event_session_events AS sese
            ON ses.event_session_id = sese.event_session_id
        JOIN sys.server_event_session_actions AS sesa
            ON ses.event_session_id = sesa.event_session_id
                AND sesa.event_id = sese.event_id
        JOIN sys.dm_xe_packages AS p
            ON sesa.package = p.name
        JOIN sys.dm_xe_objects AS o
            ON p.guid = o.package_guid
                AND sesa.name = o.name
        JOIN XETypeToSQLType  AS xetst
            ON o.type_name = xetst.XETypeName
        WHERE o.object_type = 'action'
)
, cte AS (
		SELECT 
			*, ROW_NUMBER() OVER (PARTITION BY ColumnName ORDER BY TypePrecidence DESC) AS partitionid
		FROM XESession_OutputsFromDMVs
		WHERE EventSessionName = @SessionName
	)
	, XQuerycte AS (
	SELECT
		'(event/'+NodeType+'[@name="'+ColumnName+'"]/'+XMLLocation+')[1]' AS XQuery
		,STUFF((SELECT DISTINCT ',' + QUOTENAME(EventName,'''') FROM cte c1 WHERE c1.ColumnName = c.ColumnName FOR XML PATH('')),1,1,'') AS column_events
		,*
	FROM cte c
	WHERE partitionid = 1
	)
	
	
	INSERT @cols (colSQL,colname,DataType)
	SELECT 
		QUOTENAME(ColumnName) + ' = CASE WHEN event_name in ('+column_events+') THEN event_data.value(' + QUOTENAME(XQuery,'''') + ', ' + QUOTENAME(DataType,'''') + ') ELSE NULL END '  AS colSQL
		,ColumnName
		,DataType
	FROM XQuerycte
	WHERE EventSessionName = @SessionName
	ORDER BY EventSessionName, ColumnName


    DECLARE @fields AS VARCHAR(MAX);
    SELECT @fields = STUFF(fieldCase, 1, 1, '')
    FROM (
        SELECT ',' + colSQL  +  CHAR(10) + '                ' AS [text()] 
        FROM @cols FOR XML PATH('')
    ) a(fieldCase)

	IF EXISTS(
		SELECT 1
		FROM sys.server_event_sessions AS ses
				JOIN sys.server_event_session_targets AS setg
				 ON ses.event_session_id = setg.event_session_id
		WHERE ses.name = @SessionName
			AND setg.name='ring_buffer'
	)
	BEGIN
			  
		INSERT @tmp (cmd)
		SELECT 
		'
        DECLARE @xml xml =
        CONVERT
        (
            xml,
            (
            SELECT TOP (1)
                dxst.target_data
            FROM sys.dm_xe_sessions AS dxs 
            JOIN sys.dm_xe_session_targets AS dxst ON
                dxst.event_session_address = dxs.[address]
            WHERE 
                dxs.name = '''+@SessionName+'''
                AND dxst.target_name = N''ring_buffer''
            )
        );
        
        SELECT event_name
		,event_data.value(''(event/@timestamp)[1]'', ''datetime'') AS [timestamp],
        fields.*'

		
		INSERT @tmp (cmd)
		SELECT '
		FROM (
				SELECT td.query(''.'') AS event_data
				,td.value(''@name'', ''sysname'') as event_name
				,td.value(''@timestamp'', ''datetime'') as timestamp
				FROM @xml.nodes(''RingBufferTarget[1]/event'') AS q(td)
			) a
            CROSS APPLY (
            SELECT
		         '
    	INSERT @tmp (cmd)
		SELECT @fields

        INSERT @tmp
                ( cmd )
        VALUES  ( N') fields')
                  

		SELECT @SQL = ''
        --SELECT * FROM @tmp
		SELECT @SQL += cmd FROM @tmp
	
		select @SQL
	END
	

