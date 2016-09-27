IF (OBJECT_ID(&#39;dbo.CalculateCardHistory_8k&#39;) IS NOT NULL)
	DROP PROCEDURE dbo.CalculateCardHistory_8k;
GO
IF (EXISTS (SELECT NULL FROM sys.types WHERE [name]=&#39;CardHistory_8k_type&#39;))
	DROP TYPE dbo.CardHistory_8k_type;
GO
IF (OBJECT_ID(&#39;dbo.CardHistory_8k&#39;) IS NOT NULL)
	DROP TABLE dbo.CardHistory_8k;
GO

CREATE TABLE dbo.CardHistory_8k (
	CardID		int NOT NULL,
	Cards		char(8000) COLLATE Finnish_Swedish_100_BIN2 NOT NULL,
	PRIMARY KEY NONCLUSTERED (CardID)
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_ONLY);

GO
CREATE TYPE dbo.CardHistory_8k_type AS TABLE (
	CardID		int NOT NULL,
	Cards		char(8000) COLLATE Finnish_Swedish_100_BIN2 NOT NULL,
	PRIMARY KEY NONCLUSTERED (CardID)
) WITH (MEMORY_OPTIMIZED=ON);

GO
CREATE PROCEDURE dbo.CalculateCardHistory_8k
	@s		int OUTPUT,
	@l		int OUTPUT,
	@w		int OUTPUT,
	@b		int OUTPUT,
	@tbl	dbo.CardHistory_8k_type READONLY
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS

BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL=SERIALIZABLE, LANGUAGE=&#39;us_english&#39;, DELAYED_DURABILITY=ON);

	DECLARE @CardID int=1, @count int, @rank tinyint=0, @score tinyint=0, @cards tinyint=0,
			@str char(8000)=&#39;&#39;, @ace bit=0, @status char(1)=&#39; &#39;, @offset smallint=1,
			@result varchar(8000)=&#39;&#39;, @ch char(1);

	WHILE (@str IS NOT NULL) BEGIN;

		SET @str=NULL;

		SELECT @str=Cards, @offset=1, @result=&#39;&#39;
		FROM @tbl WHERE CardID=@CardID;

		WHILE (@offset<=8000 AND @str IS NOT NULL) BEGIN;

			SET @ch=SUBSTRING(@str, @offset, 1);
			IF (@ch!=&#39;&#39;) BEGIN;
				SELECT @cards=@cards+1, @rank=CAST(@ch AS tinyint);

				IF (@rank=0) SET @rank=10;
				ELSE IF (@rank=1) SET @ace=1;

				SET @score=@score+@rank;

				IF (@score>=17 OR @ace=1 AND @score BETWEEN 7 AND 11) BEGIN;
					IF (@score>=17 AND @score<21 OR @ace=1 AND @score>=7 AND @score<11) SELECT @status=&#39;S&#39;, @s=@s+1;
					ELSE IF (@score>21) SELECT @status=&#39;L&#39;, @l=@l+1;
					ELSE IF ((@score=21 OR @score=11 AND @ace=1) AND @cards>2) SELECT @status=&#39;W&#39;, @w=@w+1;
					ELSE IF (@score=11 AND @ace=1 AND @cards=2) SELECT @status=&#39;B&#39;, @b=@b+1;

					SELECT @score=0, @cards=0, @ace=0, @result=@result+@status;
				END;
				ELSE SET @result=@result+&#39;_&#39;;
			END;

			SELECT @CardID=@CardID+1, @offset=@offset+1;
		END;

		IF (@str IS NOT NULL)
			INSERT INTO dbo.CardHistory_8k (CardID, Cards)
			VALUES (@CardID-8000, @result);
	END;
END;

GO


... och lösningsscriptet: 
SET NOCOUNT ON;

BEGIN TRANSACTION;

	DECLARE @s int=0, @l int=0, @w int=0, @b int=0,
	        @offset int=1, @cards char(8000), @CardCount int;

	CREATE TABLE #temp (
		CardID		int NOT NULL,
		Cards		char(8000) COLLATE Finnish_Swedish_100_BIN2 NOT NULL,
		PRIMARY KEY CLUSTERED (CardID)
	);

	CREATE TABLE #batches (
		CardID		int NOT NULL,
		PRIMARY KEY CLUSTERED (CardID)
	);

	SET @CardCount=(SELECT MAX(CardID) FROM dbo.CardHistory);

	--- Vi anv&#228;nder #batches-tabellen f&#246;r att kunna skapa en parallell
	--- CROSS APPLY-l&#246;sning. Tabellvariabler och in-memory-tabeller g&#229;r
	--- inte att parallellisera, s&#229; det blir en helt vanlig temptabell.
	WITH cte AS (
		SELECT 1 AS CardID UNION ALL
		SELECT CardID+8000 FROM cte WHERE CardID+8000<@CardCount)
	INSERT INTO #batches (CardID)
	SELECT CardID FROM cte
	OPTION (MAXRECURSION 0);

	--- Och av samma anledning mellanlagrar vi str&#228;ngblobbarna i en
	--- vanlig temptabell f&#246;r att sedan lyfta &#246;ver dem i en in-
	--- memory-tabellvariabel.
	INSERT INTO #temp (CardID, Cards)
	SELECT b.CardID, CAST(x.Cards AS char(8000)) AS Cards
	FROM #batches AS b
	CROSS APPLY (
		SELECT (CASE WHEN h2.[Rank]<10 THEN h2.[Rank] ELSE 0 END)
		FROM dbo.CardHistory AS h2
		WHERE h2.CardID>=b.CardID AND h2.CardID<b.CardID+8000
		ORDER BY h2.CardID
		FOR XML PATH(&#39;&#39;), TYPE) AS x(Cards)
	--- Trace flag f&#246;r att tvinga parallellism, eftersom fr&#229;gan annars
	--- blir "f&#246;r billig" och k&#246;rs seriellt trots v&#229;r vackra nested
	--- loop/apply-pattern.
	OPTION (QUERYTRACEON 8649);

	DECLARE @tbl dbo.CardHistory_8k_type;

	INSERT INTO @tbl (CardID, Cards)
	SELECT CardID, Cards FROM #temp;

	--- ... och skicka in allt i proceduren:
	EXECUTE dbo.CalculateCardHistory_8k
		@s=@s OUTPUT, @l=@l OUTPUT, @w=@w OUTPUT, @b=@b OUTPUT, @tbl=@tbl;

	--- Processa utdatan:
	WHILE (1=1) BEGIN;
		--- H&#228;mta en 8000 tecken l&#229;ng textstr&#228;ng, char(8000):
		SELECT @cards=Cards
		FROM dbo.CardHistory_8k WITH (SERIALIZABLE)
		WHERE CardID=@offset;

		IF (@@ROWCOUNT=0) BREAK;

		--- ... och UPDATE&#39;a in den i dbo.CardHistory:
		UPDATE dbo.CardHistory
		SET [Status]=SUBSTRING(@cards, CardID+1-@offset, 1)
		WHERE CardID>=@offset AND CardID<@offset+8000 AND
		      SUBSTRING(@cards, CardID+1-@offset, 1)!=&#39;_&#39;;

		SET @offset=@offset+8000;
	END;

	--- Uppdatera dbo.DealerStatus:
	TRUNCATE TABLE dbo.DealerStatus;

	INSERT INTO dbo.DealerStatus
	VALUES (&#39;B&#39;, @b), (&#39;L&#39;, @l),
		   (&#39;S&#39;, @s), (&#39;W&#39;, @w);

COMMIT TRANSACTION WITH (DELAYED_DURABILITY=ON);

--DROP TABLE #batches;
--DROP TABLE #temp;