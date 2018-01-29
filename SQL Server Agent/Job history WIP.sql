with jobs as (
	select  job_id, 
			[JobName] = name 
	from msdb.dbo.sysjobs
    WHERE name LIKE 'DWH NFW%'
),
steps as (
	select 
		job_id, 
		step_id,
		[StepName] = step_name, 
		command, 
		[LastStepRunTime] = case 
								when last_run_date > 0 and last_run_time > 0
									then msdb.dbo.agent_datetime(last_run_date, last_run_time)
								else null
							end,
		[LastStepRunDurationMinutes] = ((last_run_duration/10000*3600 + (last_run_duration/100)%100*60 + last_run_duration%100 + 31 ) / 60)
	
	from msdb.dbo.sysjobsteps
),
jobRuntimeInfo as (
		select 
			[LatestJobTotalRunDurationMinutes] = sum([LastStepRunDurationMinutes]),
			LatestJobStepCompletionTime = max([LastStepRunTime]),
			job_id
		from steps
		group by job_id
),
jobSchedule as (
	select  sjsh.job_id , 
			[NextJobStartDateTime] = nextJobStartDateTime,
			[JobScheduleStatus] = case sh.enabled
										when 1 then 'Enabled'
										when 0 then 'Disabled'
										else 'Unscheduled'
									end,
			[NextJobExtpectedFinishTime] = Dateadd(minute,jri.LatestJobTotalRunDurationMinutes, nextJobStartDateTime)
	from msdb.dbo.sysjobschedules sjsh
	inner join msdb.dbo.sysschedules  sh on sh.schedule_id = sjsh.schedule_id
	inner join jobRuntimeInfo jri on jri.job_id = sjsh.job_id
	cross apply (
		select case
					when next_run_date > 0 and next_run_time > 0
						then msdb.dbo.agent_datetime(next_run_date, next_run_time)
					else null
			   end
		) c(nextJobStartDateTime)
	where nextJobStartDateTime > GETDATE() -- If schedule is not set to run be run in the future, we ignore it.
)
, latestJobs as (
select  job_id, 
		step_id,
        [StepRunDateTime] = [RunDateTime],
        [StepRunDurationMinutes] = [RunDurationMinutes],
        [StepEndTime] = [StepEndTime],
		[LatestStepRunStatus] = case run_status
									when 0 THEN 'Failed'
									WHEN 1 THEN 'Succeeded'
									WHEN 2 THEN 'Retry'
									WHEN 3 THEN 'Canceled'
								end
from (
		select 
				[RunDateTime] = calculated.RunDateTime,
				[RunDurationMinutes] = calculated.RunDurationMinutes,
				j.job_id,
				h.step_id,
				run_status,
                StepEndTime = DATEADD(MINUTE, RunDurationMinutes, RunDateTime),
				rn = ROW_NUMBER() over (partition by j.job_id, h.step_id order by calculated.RunDateTime Desc)
		From jobs j 
		INNER JOIN msdb.dbo.sysjobhistory h 
			ON j.job_id = h.job_id 
		CROSS APPLY (
			values(	msdb.dbo.agent_datetime(run_date, run_time),
					((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)
					)
			) calculated(RunDateTime, RunDurationMinutes)
	) history
where rn = 1
),
stepHistory AS (
    SELECT j.job_id,
           j.JobName,
           h.instance_id,
           h.step_id,
           h.step_name,
           h.sql_message_id,
           h.sql_severity,
           h.message,
           h.run_status,
           h.run_date,
           h.run_time,
           h.run_duration,
           h.retries_attempted,
           h.server,
           calculated.RunDateTime,
           calculated.RunDurationMinutes
    From jobs j 
	INNER JOIN msdb.dbo.sysjobhistory h 
		ON j.job_id = h.job_id 
	CROSS APPLY (
		values(	msdb.dbo.agent_datetime(run_date, run_time),
				((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)
				)
		) calculated(RunDateTime, RunDurationMinutes)
),
jobActivityInfo as (
		-- get info about running jobs
        SELECT
			job.job_id, 
			[JobStartedAt] = activity.run_requested_date, 
            activity.start_execution_date,
            activity.last_executed_step_id,
            activity.last_executed_step_date,
            activity.stop_execution_date,
			[ElapsedMinutes] = DATEDIFF( minute, activity.run_requested_date, GETDATE() )
		FROM jobs job
		JOIN msdb.dbo.sysjobactivity activity
			ON job.job_id = activity.job_id
		JOIN msdb.dbo.syssessions sess
			ON 	sess.session_id = activity.session_id
			-- important to get only current sessions
		JOIN
		(
			SELECT max_agent_start_date = MAX(agent_start_date)
			FROM msdb.dbo.syssessions
		) sess_max
			ON sess.agent_start_date = sess_max.max_agent_start_date
		WHERE 1=1
			and run_requested_date IS NOT NULL 
            AND stop_execution_date IS NULL
)

select  jobs.JobName, 
        [Step.StepName] = st.StepName, 
        [Step.Id] = st.step_id,
		[Step.LatestStepStartedAt] = st.LastStepRunTime, 
		[Step.LatestStepCompletionTime] = timing.LatestJobStepCompletionTime, 
		[Step.LatestStepDuration] = st.LastStepRunDurationMinutes, 
		[Step.LatestStepExecutionStatus] = lj.LatestStepRunStatus, 
		
		timing.LatestJobTotalRunDurationMinutes, 
		
	 --   [Schedule.ScheduledNextJobStartDateTime] = js.NextJobStartDateTime, 
		--[Schedule.NextJobExtpectedFinishTime] = js.NextJobExtpectedFinishTime,
		--[Schedule.ScheduleStatus] = COALESCE(js.JobScheduleStatus, 'Not Scheduled'),
		
        [JobIsRunning.StartedAt] = activity.JobStartedAt,
        [JobIsRunning.StepStartedAt] = [StepRunDateTime], -- how to,
        [JobIsRunning.StepIsRunning] = CASE WHEN st.step_id = activity.last_executed_step_id + 1 THEN 1 ELSE 0 end,
		[JobIsRunning.ElapsedMinutes] = activity.ElapsedMinutes,
		[JobIsRunning.ExpectedFinish] = DATEADD(minute, LatestJobTotalRunDurationMinutes, activity.JobStartedAt)
from  jobs
inner join steps st 
	on jobs.job_id = st.job_id
left outer join 
	jobRuntimeInfo timing  
	on jobs.job_id = timing.job_id
left outer join jobSchedule js
	on js.job_id = jobs.job_id
left outer join latestJobs lj
	on jobs.job_id = lj.job_id
	   and lj.step_id = st.step_id
left outer join jobActivityInfo activity
	on activity.job_id = jobs.job_id
order by JobName, st.step_id


