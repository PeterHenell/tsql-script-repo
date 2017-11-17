-- the problem with this query is that the sys views are database specific so it cannot show the name of the objects from other database than the current one

SET TRAN ISOLATION LEVEL READ UNCOMMITTED;

-- drop table #objects
IF OBJECT_ID('tempdb..#objects') IS NULL
begin
    CREATE TABLE #objects(db_name sysname, name sysname, object_id BIGINT, principal_id BIGINT, schema_id BIGINT, parent_object_id BIGINT, type VARCHAR(40), type_desc VARCHAR(max), create_date DATETIME2, modify_date DATETIME2, is_ms_shipped BIT, is_published BIT, is_schema_published BIT);
    INSERT INTO #objects
    EXEC sys.sp_MSforeachdb @command1 = N'select db_name = ''?'', * from ?.sys.objects where is_ms_shipped = 0';

    CREATE UNIQUE CLUSTERED INDEX [CIX_Temp_objects] ON #objects (object_id, db_name)
END;

WITH locks AS (
    SELECT 
        l_blocker.request_mode ,
        l_blocker.resource_type ,
        l_blocker.resource_subtype ,
        l_blocker.resource_database_id,
        l_blocker.resource_description ,
        [object_id] = TRY_CAST(resource_associated_entity_id AS bigint) ,
        l_blocker.request_type ,
        l_blocker.request_status ,
        l_blocker.request_session_id ,
        l_blocker.request_owner_type ,
        l_blocker.request_owner_id,
       
        [Ref Count] = SUM(l_blocker.request_reference_count),
        [Lifetime] = SUM(l_blocker.request_lifetime) ,
        lockCount = COUNT_BIG(*)
    FROM 
    sys.dm_tran_locks AS l_blocker
    GROUP BY l_blocker.request_mode,
            l_blocker.resource_type,
            l_blocker.resource_subtype,
            l_blocker.resource_description,
            TRY_CAST(resource_associated_entity_id AS bigint),
            --l_blocker.resource_lock_partition,
            l_blocker.request_type,
            l_blocker.request_status,
            l_blocker.request_session_id,
            l_blocker.request_owner_type,
            l_blocker.request_owner_id,
            resource_database_id
            --DB_NAME(l_blocker.resource_database_id )
)

SELECT o.name,* 
FROM locks l
LEFT JOIN #objects o
    ON l.[object_id] = o.object_id AND DB_NAME(l.resource_database_id) = o.db_name


--LEFT JOIN sys.partitions p  WITH (NOLOCK)
--    ON p.hobt_id = l_blocker.resource_associated_entity_id

--LEFT JOIN sys.partitions tp  WITH (NOLOCK)
--    ON tp.hobt_id = l_blocker.resource_associated_entity_id


--CROSS APPLY (
--    SELECT  
--        COALESCE(OBJECT_NAME(p.object_id, DB_ID(DB_NAME(l_blocker.resource_database_id ))) ,
--                 OBJECT_NAME(p.index_id, DB_ID(DB_NAME(l_blocker.resource_database_id )))),
--       COALESCE(OBJECT_NAME(tp.object_id, DB_ID(DB_NAME(l_blocker.resource_database_id ))) ,
--                OBJECT_NAME(tp.index_id, DB_ID(DB_NAME(l_blocker.resource_database_id ))))

--) names(object_name, index_name)

--SELECT OBJECT_NAME(325576198, DB_ID('DW_0_Admin'))
--SELECT  DB_ID('DW_0_Admin')

--SELECT * FROM CubeUsageDB.sys.partitions WHERE hobt_id = 72057671269613568
--SELECT * FROM CubeUsageDB.sys.allocation_units WHERE allocation_unit_id = 72057671269613568
--SELECT * FROM CubeUsageDB.sys.objects WHERE OBJECT_ID = 72057671269613568
                        

--SELECT OBJECT_NAME(72057671269613568, DB_ID('CubeUsageDB'))
