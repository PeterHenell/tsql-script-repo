select  
   'Parameter_name' = name,  
   'Type'   = type_name(user_type_id),  
   'Length'   = max_length,  
   'Prec'   = case when type_name(system_type_id) = 'uniqueidentifier' 
              then precision  
              else OdbcPrec(system_type_id, max_length, precision) end,  
   'Scale'   = OdbcScale(system_type_id, scale),  
   'Param_order'  = parameter_id,  
   'Collation'   = convert(sysname, 
                   case when system_type_id in (35, 99, 167, 175, 231, 239)  
                   then ServerProperty('collation') end)  

  from sys.parameters where object_id = object_id('ETL.fillCounterpart')


  SELECT COUNT(*), OBJECT_ID FROM sys.parameters GROUP BY OBJECT_ID
  
  SELECT 'ColumnName' = name,  
   'Type'   = type_name(system_type_id),  
   'Length'   = max_length,  
   'Prec'   = case when type_name(system_type_id) = 'uniqueidentifier' 
              then precision  
              else OdbcPrec(system_type_id, max_length, precision) end,  
   'Scale'   = OdbcScale(system_type_id, scale),  
   'Collation'   = convert(sysname, 
                   case when system_type_id in (35, 99, 167, 175, 231, 239)  
                   then ServerProperty('collation') end),
    'TypeDef' = CASE 
                    WHEN OdbcScale(system_type_id, scale) IS NULL THEN CONCAT(TYPE_NAME(system_type_id) , '(', max_length, ')')
                    ELSE CONCAT(TYPE_NAME(system_type_id), '(', OdbcPrec(system_type_id, max_length, precision),',', OdbcScale(system_type_id, scale),')')
                END 
  FROM sys.dm_exec_describe_first_result_set_for_object(object_id('sys.sp_who2'), 1) r
  ORDER BY column_ordinal;

  EXEC sys.sp_who2
  SELECT OBJECT_ID('sp_who2')

  WITH paramValues(DataTyp, VALUE) AS(
    SELECT 'uniqueidentifier', 'A8ABE1E2-90B9-40F6-9A23-4160D47B275F' UNION ALL 
    SELECT 'date', '2012-10-08' UNION ALL 
    SELECT 'time', '10:14:26.033' UNION ALL 
    SELECT 'datetime2', '2012-10-08 10:14:26.033' UNION ALL 
    SELECT 'tinyint', '1' UNION ALL 
    SELECT 'smallint', '1' UNION ALL 
    SELECT 'int', '1' UNION ALL 
    SELECT 'smalldatetime', '2012-10-08' UNION ALL 
    SELECT 'datetime', '2012-10-08 10:14:26.033' UNION ALL 
    SELECT 'float', '1' UNION ALL 
    SELECT 'ntext', 'a' UNION ALL 
    SELECT 'bit', '1' UNION ALL 
    SELECT 'decimal', '1' UNION ALL 
    SELECT 'numeric', '1' UNION ALL 
    SELECT 'bigint', '1' UNION ALL 
    SELECT 'varbinary', '0x7065746572' UNION ALL 
    SELECT 'varchar', 'a' UNION ALL 
    SELECT 'char', 'a' UNION ALL 
    SELECT 'nvarchar', 'a' UNION ALL 
    SELECT 'nchar', 'a' UNION ALL 
    SELECT 'xml', '<peter>peter</peter>' UNION ALL 
    SELECT 'sysname', 'object'
)

SELECT 
   'EXEC ' + schema_name(ob.schema_id)+'.' + ob.name + CASE WHEN paramAndValue IS NOT NULL THEN ' @' + STUFF( SUBSTRING(paramAndValue, 0, LEN(paramAndValue)), 1, 1, '') + ';'
                                ELSE ';'
                            END
FROM 
    sys.objects ob
OUTER APPLY
(
    SELECT 
        pa.name + ' = ' + '''' + pv.value + '''' + ', '
    FROM
        sys.parameters pa
    INNER JOIN
        paramValues pv
        ON pv.DataTyp = TYPE_NAME(pa.system_type_id)
    WHERE 
        ob.object_id = pa.object_id
    ORDER BY pa.object_id    
    FOR XML PATH('')
        
) pa(paramAndValue)
    
WHERE 
    TYPE = 'p' AND ob.object_id = OBJECT_ID('ETL.fillCounterpart')

