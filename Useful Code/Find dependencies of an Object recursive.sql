DECLARE @referencing_entity AS sysname;
SET @referencing_entity = N'fillCountry';

WITH ObjectDepends(entity_name,referenced_schema, referenced_entity, referenced_id,referencing_id,referenced_database_name,referenced_schema_name,is_ambiguous,is_caller_dependent, referenced_class_desc, level)
AS
(
    SELECT entity_name = 
       CASE referencing_class
          WHEN 1 THEN OBJECT_NAME(referencing_id)
          WHEN 12 THEN (SELECT t.name FROM sys.triggers AS t 
                       WHERE t.object_id = sed.referencing_id)
          WHEN 13 THEN (SELECT st.name FROM sys.server_triggers AS st
                       WHERE st.object_id = sed.referencing_id) COLLATE database_default
       END
    ,referenced_schema_name
    ,referenced_entity_name
    ,referenced_id
    ,referencing_id
    ,sed.referenced_database_name
    ,sed.referenced_schema_name
    ,sed.is_ambiguous
    ,sed.is_caller_dependent
    ,sed.referenced_class_desc
    ,0 AS level 
    FROM sys.sql_expression_dependencies AS sed 
    WHERE OBJECT_NAME(referencing_id) = @referencing_entity 
    
    UNION ALL
    
    SELECT entity_name = 
       CASE sed.referencing_class
          WHEN 1 THEN OBJECT_NAME(sed.referencing_id)
          WHEN 12 THEN (SELECT t.name FROM sys.triggers AS t 
                       WHERE t.object_id = sed.referencing_id)
          WHEN 13 THEN (SELECT st.name FROM sys.server_triggers AS st
                       WHERE st.object_id = sed.referencing_id) COLLATE database_default
       END
    ,sed.referenced_schema_name
    ,sed.referenced_entity_name
    ,sed.referenced_id
    ,sed.referencing_id
    ,sed.referenced_database_name
    ,sed.referenced_schema_name
    ,sed.is_ambiguous
    ,sed.is_caller_dependent
    ,sed.referenced_class_desc
    ,level + 1   
    FROM ObjectDepends AS o
    JOIN sys.sql_expression_dependencies AS sed ON sed.referencing_id = o.referenced_id
)

SELECT entity_name AS referencing_entity, referenced_entity, referenced_class_desc, level, referencing_id, referenced_id, referenced_database_name,referenced_schema_name, is_ambiguous, is_caller_dependent
FROM ObjectDepends
ORDER BY level;