IF NOT EXISTS ( SELECT  *
                FROM    [sys].[tables]
                WHERE   [name] = N'WaitStats'
                        AND [type] = N'U' )
    CREATE TABLE [dbo].[WaitStats]
        (
          [RowNum] [BIGINT] IDENTITY(1, 1) ,
          [CaptureDate] [DATETIME] ,
          [WaitType] [NVARCHAR](120) ,
          [Wait_S] [DECIMAL](14, 2) ,
          [Resource_S] [DECIMAL](14, 2) ,
          [Signal_S] [DECIMAL](14, 2) ,
          [WaitCount] [BIGINT] ,
          [Percentage] [DECIMAL](4, 2) ,
          [AvgWait_S] [DECIMAL](14, 2) ,
          [AvgRes_S] [DECIMAL](14, 2) ,
          [AvgSig_S] [DECIMAL](14, 2)
        );
GO
CREATE CLUSTERED INDEX CI_WaitStats
ON [dbo].[WaitStats] ([RowNum], [CaptureDate]);