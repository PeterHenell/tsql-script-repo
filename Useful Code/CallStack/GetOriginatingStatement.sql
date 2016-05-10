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
IF EXISTS (SELECT * FROM sysobjects WHERE ID = OBJECT_ID('dbo.GetOriginatingStatement') AND xtype = 'P') BEGIN
	PRINT 'Dropping Procedure dbo.GetOriginatingStatement'
	DROP Procedure dbo.GetOriginatingStatement
END
GO

PRINT 'Creating Procedure dbo.GetOriginatingStatement'
GO

CREATE Procedure dbo.GetOriginatingStatement
	@RETVAL NVARCHAR(MAX) OUTPUT
AS

BEGIN

	CREATE TABLE #inp_buff (
		EventType NVARCHAR(30),
		Parameters INT,
		EventInfo NVARCHAR(255)
	)

	INSERT INTO #inp_buff
	EXEC('DBCC INPUTBUFFER(@@SPID) WITH NO_INFOMSGS')

	SELECT
		@RETVAL = EventInfo
	FROM #inp_buff

	DROP TABLE #inp_buff

END

GO

GRANT EXEC ON dbo.GetOriginatingStatement TO PUBLIC
GO
