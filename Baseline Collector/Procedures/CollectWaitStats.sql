INSERT  INTO dbo.WaitStats
        ( [WaitType]
        )
VALUES  ( 'Wait Statistics for ' + CAST(GETDATE() AS NVARCHAR(19))
        );
INSERT  INTO dbo.WaitStats
        ( [CaptureDate] ,
          [WaitType] ,
          [Wait_S] ,
          [Resource_S] ,
          [Signal_S] ,
          [WaitCount] ,
          [Percentage] ,
          [AvgWait_S] ,
          [AvgRes_S] ,
          [AvgSig_S]
        )
        EXEC ( '
 WITH [Waits] AS
 (SELECT
 [wait_type],
 [wait_time_ms] / 1000.0 AS [WaitS],
 ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0
 AS [ResourceS],
 [signal_wait_time_ms] / 1000.0 AS [SignalS],
 [waiting_tasks_count] AS [WaitCount],
 100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER()
 AS [Percentage],
 ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
 FROM sys.dm_os_wait_stats
 WHERE [wait_type] NOT IN (
 N''BROKER_EVENTHANDLER'', N''BROKER_RECEIVE_WAITFOR'',
 N''BROKER_TASK_STOP'', N''BROKER_TO_FLUSH'',
 N''BROKER_TRANSMITTER'', N''CHECKPOINT_QUEUE'',
 N''CHKPT'', N''CLR_AUTO_EVENT'',
 N''CLR_MANUAL_EVENT''
 
)
 )
 

 SELECT
 GETDATE(),
 [W1].[wait_type] AS [WaitType],
 CAST ([W1].[WaitS] AS DECIMAL(14, 2)) AS [Wait_S],
 CAST ([W1].[ResourceS] AS DECIMAL(14, 2)) AS [Resource_S],
 CAST ([W1].[SignalS] AS DECIMAL(14, 2)) AS [Signal_S],
 [W1].[WaitCount] AS [WaitCount],
 CAST ([W1].[Percentage] AS DECIMAL(4, 2)) AS [Percentage],
 CAST (([W1].[WaitS] / [W1].[WaitCount]) AS DECIMAL (14, 4))
 AS [AvgWait_S],
 CAST (([W1].[ResourceS] / [W1].[WaitCount]) AS DECIMAL (14, 4))
 AS [AvgWait_S],
 CAST (([W1].[ResourceS] / [W1].[WaitCount]) AS DECIMAL (14, 4))
 AS [AvgRes_S],
 CAST (([W1].[SignalS] / [W1].[WaitCount]) AS DECIMAL (14, 4))
 AS [AvgSig_S]
 FROM [Waits] AS [W1]
 INNER JOIN [Waits] AS [W2]
 ON [W2].[RowNum] <= [W1].[RowNum]
 GROUP BY [W1].[RowNum], [W1].[wait_type], [W1].[WaitS],
 [W1].[ResourceS], [W1].[SignalS], [W1].[WaitCount],
 [W1].[Percentage]
 HAVING SUM ([W2].[Percentage]) - [W1].[Percentage] < 95;’
 );
 '
            );
GO