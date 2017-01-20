DECLARE @tbl INT;
SELECT @tbl = OBJECT_ID('mx3.RTA_CONTRACT_REP');

SELECT o.name, s.stats_id, s.name, s.auto_created, s.user_created,
       substring(scols.cols, 3, len(scols.cols)) AS stat_cols,
       stats_date(o.object_id, s.stats_id) AS stats_date,
       s.filter_definition
FROM   sys.objects o
JOIN   sys.stats s ON s.object_id = o.object_id
cross  APPLY (SELECT ', ' + c.name
              FROM   sys.stats_columns sc
              JOIN   sys.columns c ON sc.object_id = c.object_id
                                  AND sc.column_id = c.column_id
              WHERE  sc.object_id = s.object_id
                AND  sc.stats_id  = s.stats_id
              ORDER  BY sc.stats_column_id
              FOR XML PATH('')) AS scols(cols)
WHERE  o.object_id = @tbl
ORDER  BY o.name, s.stats_id

-- DBCC SHOW_STATISTICS ([MX3.RTA_CONTRACT_REP],M_PACK_REF) with Histogram