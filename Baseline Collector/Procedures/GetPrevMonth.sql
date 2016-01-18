SELECT  [w].[CaptureDate] ,
        [w].[WaitType] ,
        [w].[Percentage] ,
        [w].[Wait_S] ,
        [w].[WaitCount] ,
        [w].[AvgWait_S]
FROM    [dbo].[WaitStats] w
        JOIN ( SELECT   MIN([RowNum]) AS [RowNumber] ,
                        [CaptureDate]
               FROM     [dbo].[WaitStats]
               WHERE    [CaptureDate] IS NOT NULL
                        AND [CaptureDate] > GETDATE() - 30
               GROUP BY [CaptureDate]
             ) m ON [w].[RowNum] = [m].[RowNumber]
ORDER BY [w].[CaptureDate];