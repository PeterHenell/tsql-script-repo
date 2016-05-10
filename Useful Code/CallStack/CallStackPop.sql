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
IF EXISTS (SELECT * FROM sysobjects WHERE ID = OBJECT_ID('dbo.CallStackPop') AND xtype = 'P') BEGIN
	PRINT 'Dropping Procedure dbo.CallStackPop'
	DROP PROCEDURE dbo.CallStackPop
END
GO

PRINT 'Creating Procedure dbo.CallStackPop'
GO

CREATE Procedure dbo.CallStackPop
AS

SET NOCOUNT ON

DECLARE @BIN VARBINARY(128)
SELECT @BIN = ISNULL(CONTEXT_INFO(), CAST('' AS VARBINARY(1)))
SELECT @BIN = SUBSTRING(@BIN, 5, 128)

SET CONTEXT_INFO @BIN

GO

GRANT EXEC ON dbo.CallStackPop TO PUBLIC
GO
