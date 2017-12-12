--CREATE DATABASE PeterDB;
--GO
--USE PeterDB
--GO
--CREATE SCHEMA Fact AUTHORIZATION dbo;
--go

-- Create the partition function for the large fact table
-- For this demo, partitions are three months in size (which is not realistic)
CREATE PARTITION FUNCTION pfDateKey (datetime) 
AS RANGE RIGHT
   FOR VALUES( '20140101', '20140401', '20140701', '20141001',
               '20150101', '20150401', '20150701', '20151001',
               '20160101', '20160401', '20160701', '20161001',
               '20170101', '20170401', '20170701', '20171001'
              )

-- Create the partition scheme
-- (Partition swapping requires all partitions to be on the same filegroup)
CREATE PARTITION SCHEME psDateKey
AS PARTITION pfDateKey ALL TO ([PRIMARY]);

CREATE TABLE [Fact].[f_Peter](
	[SysExecutionLog_key] [int] NOT NULL,
	[SysDatetimeInsertedUTC] [datetime2](0) NOT NULL,
	[SysDatetimeUpdatedUTC] [datetime2](0) NULL,
	[SysModifiedUTC] [datetime2](0) NOT NULL,
	[SysValidFromDateTime] [datetime2](0) NOT NULL,
	[SysDatetimeDeletedUTC] [datetime2](0) NULL,
	[TransactionId] [int] NULL,
	[TransactionLineId] [int] NULL,
	[GLTransactions_key] [nvarchar](100) NOT NULL,
	[ChartofAccount_key] [int] NULL,
	[CostCenter_key] [int] NULL,
	[Currency_TCY_key] [int] NULL,
	[Currency_LCY_key] [int] NULL,
	[Subsidiary_key] [int] NULL,
	[Market_key] [int] NULL,
	[Opportunity_key] [int] NULL,
	[ProductCategory_key] [int] NULL,
	[Partner_key] [int] NULL,
	[Project_key] [int] NULL,
	[Calendar_TransactionDate_bkey] [datetime] NULL,
	[Calendar_TransactionDate_key] [int] NULL,
	[Calendar_AccountingPeriod_bkey] [datetime] NULL,
	[Calendar_AccountingPeriod_key] [int] NULL,
	[Journal_key] [int] NULL,
	[AccountingPeriod] [nvarchar](100) NULL,
	[InvoiceNo] [nvarchar](100) NULL,
	[TransactionDescription] [nvarchar](500) NULL,
	[AmountTCY] [decimal](16, 2) NULL,
	[AmountLCY] [decimal](16, 2) NULL,
	[AmountVATTCY] [decimal](16, 2) NULL,
	[AmountVATLCY] [decimal](16, 2) NULL,
	[Vendor_Transaction_key] [int] NULL,
	[Vendor_TransactionLine_key] [int] NULL,
	[Customer_Transaction_key] [int] NULL,
	[Customer_TransactionLine_key] [int] NULL,
	[SysDataSource] [nvarchar](10) NULL,
	[JournalClassification_key] [int] NULL,
	[JournalEntryType_key] [int] NULL,
 ) ON psDateKey([Calendar_AccountingPeriod_bkey]);;

CREATE TABLE [Fact].[f_Peter_Staging](
	[SysExecutionLog_key] [int] NOT NULL,
	[SysDatetimeInsertedUTC] [datetime2](0) NOT NULL,
	[SysDatetimeUpdatedUTC] [datetime2](0) NULL,
	[SysModifiedUTC] [datetime2](0) NOT NULL,
	[SysValidFromDateTime] [datetime2](0) NOT NULL,
	[SysDatetimeDeletedUTC] [datetime2](0) NULL,
	[TransactionId] [int] NULL,
	[TransactionLineId] [int] NULL,
	[GLTransactions_key] [nvarchar](100) NOT NULL,
	[ChartofAccount_key] [int] NULL,
	[CostCenter_key] [int] NULL,
	[Currency_TCY_key] [int] NULL,
	[Currency_LCY_key] [int] NULL,
	[Subsidiary_key] [int] NULL,
	[Market_key] [int] NULL,
	[Opportunity_key] [int] NULL,
	[ProductCategory_key] [int] NULL,
	[Partner_key] [int] NULL,
	[Project_key] [int] NULL,
	[Calendar_TransactionDate_bkey] [datetime] NULL,
	[Calendar_TransactionDate_key] [int] NULL,
	[Calendar_AccountingPeriod_bkey] [datetime] NULL,
	[Calendar_AccountingPeriod_key] [int] NULL,
	[Journal_key] [int] NULL,
	[AccountingPeriod] [nvarchar](100) NULL,
	[InvoiceNo] [nvarchar](100) NULL,
	[TransactionDescription] [nvarchar](500) NULL,
	[AmountTCY] [decimal](16, 2) NULL,
	[AmountLCY] [decimal](16, 2) NULL,
	[AmountVATTCY] [decimal](16, 2) NULL,
	[AmountVATLCY] [decimal](16, 2) NULL,
	[Vendor_Transaction_key] [int] NULL,
	[Vendor_TransactionLine_key] [int] NULL,
	[Customer_Transaction_key] [int] NULL,
	[Customer_TransactionLine_key] [int] NULL,
	[SysDataSource] [nvarchar](10) NULL,
	[JournalClassification_key] [int] NULL,
	[JournalEntryType_key] [int] NULL
) ON psDateKey([Calendar_AccountingPeriod_bkey]);
GO


CREATE CLUSTERED INDEX [NCIDX_Calendar_AccountingPeriod_bkey_Fact_f_Peter_Staging] ON [Fact].[f_Peter_Staging]
(
	[Calendar_AccountingPeriod_bkey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
ON psDateKey([Calendar_AccountingPeriod_bkey])



INSERT Fact.f_Peter WITH(TABLOCK)
(
    SysExecutionLog_key,
    SysDatetimeInsertedUTC,
    SysDatetimeUpdatedUTC,
    SysModifiedUTC,
    SysValidFromDateTime,
    SysDatetimeDeletedUTC,
    TransactionId,
    TransactionLineId,
    GLTransactions_key,
    ChartofAccount_key,
    CostCenter_key,
    Currency_TCY_key,
    Currency_LCY_key,
    Subsidiary_key,
    Market_key,
    Opportunity_key,
    ProductCategory_key,
    Partner_key,
    Project_key,
    Calendar_TransactionDate_bkey,
    Calendar_TransactionDate_key,
    Calendar_AccountingPeriod_bkey,
    Calendar_AccountingPeriod_key,
    Journal_key,
    AccountingPeriod,
    InvoiceNo,
    TransactionDescription,
    AmountTCY,
    AmountLCY,
    AmountVATTCY,
    AmountVATLCY,
    Vendor_Transaction_key,
    Vendor_TransactionLine_key,
    Customer_Transaction_key,
    Customer_TransactionLine_key,
    SysDataSource,
    JournalClassification_key,
    JournalEntryType_key
)
SELECT * FROM DWH_3_Fact.Fact.f_GLTransactions WHERE Calendar_AccountingPeriod_bkey < '2017-10-01';

/*
drop index NCI_Fact_f_Peter
    ON [Fact].[f_Peter]
ALTER INDEX NCI_Fact_f_Peter
    ON [Fact].[f_Peter] DISABLE;
ALTER INDEX NCI_Fact_f_Peter
    ON [Fact].[f_Peter] REBUILD;

drop index [NCIDX_Calendar_AccountingPeriod_bkey_Fact_f_Peter] ON [Fact].[f_Peter];
*/

CREATE CLUSTERED INDEX [NCIDX_Calendar_AccountingPeriod_bkey_Fact_f_Peter] ON [Fact].[f_Peter]
(
	[Calendar_AccountingPeriod_bkey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
ON psDateKey([Calendar_AccountingPeriod_bkey]);


--DROP INDEX NCI_Fact_f_Peter ON [Fact].[f_Peter]
CREATE NONCLUSTERED COLUMNSTORE INDEX NCI_Fact_f_Peter ON [Fact].[f_Peter]
(
 SysExecutionLog_key,
    SysDatetimeInsertedUTC,
    SysDatetimeUpdatedUTC,
    SysModifiedUTC,
    SysValidFromDateTime,
    SysDatetimeDeletedUTC,
    TransactionId,
    TransactionLineId,
    GLTransactions_key,
    ChartofAccount_key,
    CostCenter_key,
    Currency_TCY_key,
    Currency_LCY_key,
    Subsidiary_key,
    Market_key,
    Opportunity_key,
    ProductCategory_key,
    Partner_key,
    Project_key,
    Calendar_TransactionDate_bkey,
    Calendar_TransactionDate_key,
    Calendar_AccountingPeriod_bkey,
    Calendar_AccountingPeriod_key,
    Journal_key,
    AccountingPeriod,
    InvoiceNo,
    TransactionDescription,
    AmountTCY,
    AmountLCY,
    AmountVATTCY,
    AmountVATLCY,
    Vendor_Transaction_key,
    Vendor_TransactionLine_key,
    Customer_Transaction_key,
    Customer_TransactionLine_key,
    SysDataSource,
    JournalClassification_key,
    JournalEntryType_key
) WITH(MAXDOP=1);


--INSERT [Fact].[f_Peter_Staging]
--SELECT * FROM DWH_3_Fact.Fact.f_GLTransactions WHERE Calendar_AccountingPeriod_bkey >= '2017-10-01';
CREATE NONCLUSTERED COLUMNSTORE INDEX NCI_Fact_f_Peter_Staging ON [Fact].[f_Peter_Staging]
(
 SysExecutionLog_key,
    SysDatetimeInsertedUTC,
    SysDatetimeUpdatedUTC,
    SysModifiedUTC,
    SysValidFromDateTime,
    SysDatetimeDeletedUTC,
    TransactionId,
    TransactionLineId,
    GLTransactions_key,
    ChartofAccount_key,
    CostCenter_key,
    Currency_TCY_key,
    Currency_LCY_key,
    Subsidiary_key,
    Market_key,
    Opportunity_key,
    ProductCategory_key,
    Partner_key,
    Project_key,
    Calendar_TransactionDate_bkey,
    Calendar_TransactionDate_key,
    Calendar_AccountingPeriod_bkey,
    Calendar_AccountingPeriod_key,
    Journal_key,
    AccountingPeriod,
    InvoiceNo,
    TransactionDescription,
    AmountTCY,
    AmountLCY,
    AmountVATTCY,
    AmountVATLCY,
    Vendor_Transaction_key,
    Vendor_TransactionLine_key,
    Customer_Transaction_key,
    Customer_TransactionLine_key,
    SysDataSource,
    JournalClassification_key,
    JournalEntryType_key
) WITH(MAXDOP=1)

;


-- ***************************************
-- Setup complete
-- ***************************************

-- First, disable the columnstore index on the staging table, to allow changes
ALTER INDEX NCI_Fact_f_Peter_Staging
    ON [Fact].[f_Peter_Staging] DISABLE;


    INSERT Fact.f_Peter_Staging
    (
        SysExecutionLog_key,
        SysDatetimeInsertedUTC,
        SysDatetimeUpdatedUTC,
        SysModifiedUTC,
        SysValidFromDateTime,
        SysDatetimeDeletedUTC,
        TransactionId,
        TransactionLineId,
        GLTransactions_key,
        ChartofAccount_key,
        CostCenter_key,
        Currency_TCY_key,
        Currency_LCY_key,
        Subsidiary_key,
        Market_key,
        Opportunity_key,
        ProductCategory_key,
        Partner_key,
        Project_key,
        Calendar_TransactionDate_bkey,
        Calendar_TransactionDate_key,
        Calendar_AccountingPeriod_bkey,
        Calendar_AccountingPeriod_key,
        Journal_key,
        AccountingPeriod,
        InvoiceNo,
        TransactionDescription,
        AmountTCY,
        AmountLCY,
        AmountVATTCY,
        AmountVATLCY,
        Vendor_Transaction_key,
        Vendor_TransactionLine_key,
        Customer_Transaction_key,
        Customer_TransactionLine_key,
        SysDataSource,
        JournalClassification_key,
        JournalEntryType_key
    )
    SELECT * FROM DWH_3_Fact.Fact.f_GLTransactions WHERE Calendar_AccountingPeriod_bkey >= '2017-11-01';


ALTER INDEX NCI_Fact_f_Peter_Staging
    ON [Fact].[f_Peter_Staging] REBUILD;

-- Add a constraint to ensure we only have data for Q1 of 2010 (the "next" partition)
ALTER TABLE [Fact].[f_Peter_Staging]
ADD CONSTRAINT CK_Correct_Partition
        CHECK (Calendar_AccountingPeriod_bkey >= '20171001' AND Calendar_AccountingPeriod_bkey < '20180101')
        

SELECT COUNT(*) FROM Fact.f_Peter_Staging
SELECT COUNT(*) FROM Fact.f_Peter


ALTER PARTITION SCHEME psDateKey
    NEXT USED [PRIMARY];

-- Switch the staging table into the partition just created for Q3 of 2017
-- First find the correct partition number (using any date in the range)
DECLARE @Part int = $PARTITION.pfDateKey('20171001');
SELECT @Part
-- Then do the actual swap
ALTER TABLE Fact.f_Peter_Staging
SWITCH PARTITION @Part TO Fact.f_Peter
       PARTITION @Part;

-- Alternate if staging is not partitioned
-- ALTER TABLE Fact.f_Peter_Staging SWITCH TO Fact.f_Peter PARTITION @Part;

SELECT COUNT(*) FROM Fact.f_Peter_Staging
SELECT COUNT(*) FROM Fact.f_Peter

    --







-- switch out existing data to staging table and then modify it, to then switch it back
drop INDEX NCI_Fact_f_Peter_Staging
    ON [Fact].[f_Peter_Staging];
ALTER TABLE [Fact].[f_Peter_Staging]
    DROP CONSTRAINT CK_Correct_Partition;

TRUNCATE TABLE Fact.f_Peter_Staging;

DECLARE @Part int = $PARTITION.pfDateKey('20171001');
SELECT @Part
-- Then do the actual swap
ALTER TABLE Fact.f_Peter
SWITCH PARTITION @Part TO Fact.f_Peter_Staging
       PARTITION @Part;


SELECT COUNT(*) FROM Fact.f_Peter_Staging
SELECT COUNT(*) FROM Fact.f_Peter


-- we are not free to modify the data in the staging table (which is holding the partition which is active for the current period)
UPDATE Fact.f_Peter_Staging SET TransactionId =0 

ALTER TABLE [Fact].[f_Peter_Staging]
ADD CONSTRAINT CK_Correct_Partition
        CHECK (Calendar_AccountingPeriod_bkey >= '20171001' AND Calendar_AccountingPeriod_bkey < '20180101')
        


CREATE NONCLUSTERED COLUMNSTORE INDEX NCI_Fact_f_Peter_Staging ON [Fact].[f_Peter_Staging]
(
 SysExecutionLog_key,
    SysDatetimeInsertedUTC,
    SysDatetimeUpdatedUTC,
    SysModifiedUTC,
    SysValidFromDateTime,
    SysDatetimeDeletedUTC,
    TransactionId,
    TransactionLineId,
    GLTransactions_key,
    ChartofAccount_key,
    CostCenter_key,
    Currency_TCY_key,
    Currency_LCY_key,
    Subsidiary_key,
    Market_key,
    Opportunity_key,
    ProductCategory_key,
    Partner_key,
    Project_key,
    Calendar_TransactionDate_bkey,
    Calendar_TransactionDate_key,
    Calendar_AccountingPeriod_bkey,
    Calendar_AccountingPeriod_key,
    Journal_key,
    AccountingPeriod,
    InvoiceNo,
    TransactionDescription,
    AmountTCY,
    AmountLCY,
    AmountVATTCY,
    AmountVATLCY,
    Vendor_Transaction_key,
    Vendor_TransactionLine_key,
    Customer_Transaction_key,
    Customer_TransactionLine_key,
    SysDataSource,
    JournalClassification_key,
    JournalEntryType_key
) WITH(MAXDOP=1);



DECLARE @Part int = $PARTITION.pfDateKey('20171001');
SELECT @Part
-- Then do the actual swap
ALTER TABLE Fact.f_Peter_Staging
SWITCH PARTITION @Part TO Fact.f_Peter
       PARTITION @Part;

SELECT * FROM Fact.f_Peter WHERE Calendar_AccountingPeriod_bkey >= '2017-10-01'