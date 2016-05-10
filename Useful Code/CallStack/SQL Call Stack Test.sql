/* ****************************************************************************
 *
 * Copyright (c) 2010 Gabriel McAdams, http://www.thecodepage.com/
 *
 * This software is subject to the Microsoft Public License (Ms-PL). 
 * A copy of the license can be found in the license.htm file included 
 * in this distribution.
 *
 * You must not remove this notice, or any other, from this software.
 *
 * ***************************************************************************/
--Inner most procedure
CREATE Procedure dbo.SP_3
AS

SET NOCOUNT ON

EXEC dbo.CallStackPush @@PROCID


SELECT * FROM dbo.CallStackView()

DECLARE @executing NVARCHAR(MAX)
EXEC dbo.GetOriginatingStatement @executing OUTPUT
SELECT @executing AS OriginatingStatement


EXEC dbo.CallStackPop

GO




--Second procedure
CREATE Procedure dbo.SP_2
AS

SET NOCOUNT ON

EXEC dbo.CallStackPush @@PROCID

exec SP_3

EXEC dbo.CallStackPop

GO





--Outer most procedure
CREATE Procedure dbo.SP_1
AS

SET NOCOUNT ON

EXEC dbo.CallStackPush @@PROCID

exec SP_2

EXEC dbo.CallStackPop

GO












GO
--Originating statement
EXEC dbo.SP_1
GO

DROP Procedure SP_3
DROP Procedure SP_2
DROP Procedure SP_1
GO
