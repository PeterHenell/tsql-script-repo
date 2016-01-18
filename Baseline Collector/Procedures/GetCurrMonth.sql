SELECT  *
FROM    [dbo].[WaitStats]
WHERE   [CaptureDate] > GETDATE() - 30
ORDER BY [RowNum];