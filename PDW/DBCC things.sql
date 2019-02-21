DBCC PDW_SHOWSPACEUSED('edm.basic_cust_lc_fct');

select * 
from metadata.CurrentRunningQueries;

SELECT distribution_id,spid ,sqlr.command, StepLocationType, *
FROM sys.dm_pdw_sql_requests sqlr
inner join metadata.CurrentRunningQueriesSteps crq on sqlr.request_id = crq.request_id
where StepLocationType <> 'Compute'


--  distribution_id and spid 
DBCC PDW_SHOWEXECUTIONPLAN(1,158);

-- Copy paste into http://supratimas.com/