SELECT 
       names.object_name,
       names.index_name,
       l_blocker.request_mode ,
       
       l_blocker.resource_type ,
       l_blocker.resource_subtype ,
       DB_NAME(l_blocker.resource_database_id ),
       l_blocker.resource_description ,
       l_blocker.resource_associated_entity_id ,
       l_blocker.resource_lock_partition ,
       l_blocker.request_type ,
       l_blocker.request_status ,
       l_blocker.request_reference_count ,
       l_blocker.request_lifetime ,
       l_blocker.request_session_id ,
       l_blocker.request_owner_type ,
       l_blocker.request_owner_id 
FROM 
    sys.dm_tran_locks AS l_blocker WITH (NOLOCK)
LEFT JOIN sys.partitions p  WITH (NOLOCK)
    ON p.hobt_id = l_blocker.resource_associated_entity_id

LEFT JOIN dwh_temp.sys.partitions tp  WITH (NOLOCK)
    ON tp.hobt_id = l_blocker.resource_associated_entity_id

CROSS APPLY (
    SELECT  
        COALESCE(OBJECT_NAME(p.object_id, l_blocker.resource_database_id) ,
                 OBJECT_NAME(p.index_id, l_blocker.resource_database_id) ),
       COALESCE(OBJECT_NAME(tp.object_id, l_blocker.resource_database_id) ,
                OBJECT_NAME(tp.index_id, l_blocker.resource_database_id))

) names(object_name, index_name)



