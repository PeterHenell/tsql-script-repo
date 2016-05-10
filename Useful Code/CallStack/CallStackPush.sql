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
IF EXISTS (SELECT * FROM sysobjects WHERE ID = OBJECT_ID('dbo.CallStackPush') AND xtype = 'P') BEGIN
	PRINT 'Dropping Procedure dbo.CallStackPush'
	DROP PROCEDURE dbo.CallStackPush
END
GO

PRINT 'Creating Procedure dbo.CallStackPush'
GO

CREATE Procedure dbo.CallStackPush
	@PROCID INT
AS

SET NOCOUNT ON

DECLARE @BIN VARBINARY(128)

SELECT @BIN = CONVERT(BINARY(4), @PROCID) + ISNULL(CONTEXT_INFO(), CAST('' AS VARBINARY(1)))

SET CONTEXT_INFO @BIN

GO

GRANT EXEC ON dbo.CallStackPush TO PUBLIC
GO
