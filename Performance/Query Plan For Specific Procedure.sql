SELECT qs.plan_handle, a.attrlist, qp.query_plan
FROM   sys.dm_exec_query_stats qs
CROSS  APPLY sys.dm_exec_sql_text(qs.sql_handle) est
CROSS  APPLY (SELECT epa.attribute + '=' + convert(nvarchar(127), epa.value) + '   '
              FROM   sys.dm_exec_plan_attributes(qs.plan_handle) epa
              WHERE  epa.is_cache_key = 1
              ORDER  BY epa.attribute
              FOR    XML PATH('')) AS a(attrlist)
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE  est.objectid = object_id ('tempdb..#loadpackage')
  AND  est.dbid     = db_id('tempdb') 