DELETE FROM [dbo].[WaitStats]
WHERE [CaptureDate] < GETDATE() - 90;