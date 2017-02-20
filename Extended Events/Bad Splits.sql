CREATE EVENT SESSION [BadSplits]
ON    SERVER
ADD EVENT sqlserver.transaction_log(
    WHERE operation = 11  -- LOP_DELETE_SPLIT
)
ADD TARGET package0.event_file
-- You need to customize the path
(SET filename=N'C:\xel\badsplits.xel')
GO
 
-- Start the session
ALTER EVENT SESSION [Blocked]
ON SERVER
STATE = start;
GO




with qry as
        (select
               -- Retrieve the database_id from inside the XML document
theNodes.event_data.value('(data[@name="database_id"]/value)[1]','int') as database_id
               from
        (select convert(xml,event_data) event_data -- convert the text field to XML
               from
-- reads the information in the event files
sys.fn_xe_file_target_read_file('c:\xel\badsplits*.xel', NULL, NULL, NULL)) theData
                cross apply theData.event_data.nodes('//event') theNodes(event_data) )
select db_name(database_id),count(*) as total from qry
group by db_name(database_id) -- group the result by database
order by total desc



with qry as
         (select
theNodes.event_data.value('(data[@name="database_id"]/value)[1]','int') as database_id,
theNodes.event_data.value('(data[@name="alloc_unit_id"]/value)[1]','varchar(30)') as alloc_unit_id,
theNodes.event_data.value('(data[@name="context"]/text)[1]','varchar(30)') as context
                 from
                          (select convert(xml,event_data) event_data
                          from
                 sys.fn_xe_file_target_read_file('c:\xel\badsplits*.xel', NULL, NULL, NULL)) theData
                  cross apply theData.event_data.nodes('//event') theNodes(event_data) )
select name,context,count(*) as total -- The count of splits by objects
 from qry,sys.allocation_units au, sys.partitions p, sys.objects ob
where qry.alloc_unit_id=au.allocation_unit_id
                 and au.container_id=p.hobt_id and p.object_id=ob.object_id
                 and (au.type=1 or au.type=3) and
                   db_name(database_id)='MDW' -- Filter by the database
group by name,context -- group by object name and context
order by name