 SET NOCOUNT ON
    DECLARE @fullObjectName sysname = 'ETL.tLargeExposure';

    IF (TYPE_ID (@fullObjectName) IS NULL)
    BEGIN
        RAISERROR ('User-defined table type ''%s'' does not exists. Include full object name with schema.', 16,1, @fullObjectName)
        RETURN
    END;

    WITH sources
    AS
    (
        SELECT ROW_NUMBER() OVER (ORDER BY OBJECT_NAME(m.object_id)) RowId, definition
        FROM sys.sql_expression_dependencies d
        JOIN sys.sql_modules m ON m.object_id = d.referencing_id
        JOIN sys.objects o ON o.object_id = m.object_id
        WHERE referenced_id = TYPE_ID(@fullObjectName)
    )
    SELECT 'BEGIN TRANSACTION'
    UNION ALL   
    SELECT 

        'DROP ' +
            CASE OBJECTPROPERTY(referencing_id, 'IsProcedure')
            WHEN 1 THEN 'PROC '
            ELSE
                CASE
                    WHEN OBJECTPROPERTY(referencing_id, 'IsScalarFunction') = 1 OR OBJECTPROPERTY(referencing_id, 'IsTableFunction') = 1 OR OBJECTPROPERTY(referencing_id, 'IsInlineFunction') = 1 THEN 'FUNCTION '
                    ELSE ''
                END
            END
        + SCHEMA_NAME(o.schema_id) + '.' +
        + OBJECT_NAME(m.object_id)    

    FROM sys.sql_expression_dependencies d
    JOIN sys.sql_modules m ON m.object_id = d.referencing_id
    JOIN sys.objects o ON o.object_id = m.object_id
    WHERE referenced_id = TYPE_ID(@fullObjectName)
    UNION  ALL
    SELECT  'GO'
    UNION ALL
    SELECT CHAR(13) + CHAR(10) + '---- WRITE HERE SCRIPT TO DROP OLD USER DEFINED TABLE TYPE AND CREATE A NEW ONE ----' + CHAR(13) + CHAR(10)
    UNION  ALL
    SELECT
        CASE
            WHEN number = RowId    THEN DEFINITION
            ELSE 'GO'
        END
     FROM sources s
    JOIN (SELECT DISTINCT number FROM master.dbo.spt_values) n ON n.number BETWEEN RowId AND RowId+1
    UNION ALL
    SELECT 'COMMIT'