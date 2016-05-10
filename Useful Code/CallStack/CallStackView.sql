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
IF EXISTS (SELECT * FROM sysobjects WHERE ID = OBJECT_ID('dbo.CallStackView') AND xtype IN (N'FN', N'IF', N'TF')) BEGIN
	PRINT 'Dropping Function dbo.CallStackView'
	DROP Function dbo.CallStackView
END
GO

PRINT 'Creating Function dbo.CallStackView'
GO

CREATE FUNCTION dbo.CallStackView()
RETURNS @result TABLE (
	SchemaId INT,
	SchemaName VARCHAR(256),
	ProcedureId INT,
	ProcedureName VARCHAR(256)
)
AS
BEGIN
	DECLARE @BIN VARBINARY(128)
	SELECT @BIN = ISNULL(CONTEXT_INFO(), CAST('' AS VARBINARY(1)))

	DECLARE @PROCID INT

	WHILE (LEN(@BIN) > 0 AND CONVERT(INT, SUBSTRING(@BIN, 1, 4)) > 0) BEGIN
		SET @PROCID = CONVERT(INT, SUBSTRING(@BIN, 1, 4))
		SET @BIN = SUBSTRING(@BIN, 5, 128)

		INSERT @result (
			SchemaId,
			SchemaName,
			ProcedureId,
			ProcedureName
		)
		SELECT
			s.schema_id,
			s.name,
			o.object_id,
			o.name
		FROM sys.objects o
		INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
		WHERE o.object_id = @PROCID

	END
    
  RETURN
END

GO

GRANT SELECT ON dbo.CallStackView TO PUBLIC
GO
