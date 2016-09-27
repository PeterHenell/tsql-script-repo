--
-- Pipeline_5, Setup
--
-- Stefan Gustafsson, Acando
--
-- Använder Service Broker för att köra ett antal parallella workers
-- Varje worker gör följande:
--   1) ladda data från CardHistory till en memory table variable
--   2) Vänta på att föregående block är klart
--   3) Processa korten i det aktuella blocket, spara resultat i memory-based ResultTable
--   4) Uppdatera CardHistory från ResultTable
--
-- Uses 5 worker threads
 
---------------------------------------------
-- Create Memory based tables
-- and native stored procedures
---------------------------------------------
 
if object_id('dbo.ProcessCards') is not null drop procedure dbo.ProcessCards
go
if object_id('dbo.ResultTable') is not null drop table dbo.ResultTable
go
CREATE TABLE dbo.ResultTable (
        CardID    int     not null,
        Status    char(1) not null,
        CONSTRAINT PK_CardID PRIMARY KEY NONCLUSTERED HASH (CardID) WITH (BUCKET_COUNT = 10000000)
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY)
go
if type_id('dbo.InputType') is not null drop type dbo.InputType
go
CREATE TYPE dbo.InputType AS TABLE (
        CardID    int     not null,
        Rank      tinyint not null,
        INDEX IX_CardID HASH (CardID) WITH ( BUCKET_COUNT = 10000000)
) WITH (MEMORY_OPTIMIZED = ON)
go
CREATE PROCEDURE dbo.ProcessCards(@Input dbo.InputType READONLY, @FirstCard int, @LastCard int, @LastPageCard int, @RS int output, @RL int output, @RW int output, @RB int output, @NextCard int output, @LastCardOnPage int output)
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'US_ENGLISH', DELAYED_DURABILITY=ON)
 
        declare @i    int = @FirstCard
        declare @Rank int
 
        declare @sum    int = 0
        declare @hasace int = 0
        declare @cards  int = 0
        declare @status char(1) = ' '
        declare @S int = @RS
        declare @L int = @RL
        declare @W int = @RW
        declare @B int = @RB
 
        declare @dummy int=0
 
        while @i <= @LastCard
        begin
                select @Rank = Rank from @Input where CardID=@i
 
                set @cards = @cards+1
 
                if @rank>10     set @rank=10
                else if @rank=1 set @hasace=1
 
                set @sum = @sum+@rank
 
                if @hasace=1 begin
                        if @sum >= 7
                        begin
                                if @sum < 11          begin set @status='S' set @S=@S+1 end
                                else if @sum = 11
                                begin
                                        if @cards=2       begin set @status='B' set @B=@B+1 end
                                        else              begin set @status='W' set @W=@W+1 end
                                end
                                else if @sum >= 17
                                begin
                                        if @sum < 21      begin set @status='S' set @S=@S+1 end
                                        else if @sum > 21 begin set @status='L' set @L=@L+1 end
                                        else              begin set @status='W' set @W=@W+1 end
                                end
                        end
                end else begin
                        if @sum >= 17
                        begin
                                if @sum < 21          begin set @status='S' set @S=@S+1 end
                                else if @sum > 21     begin set @status='L' set @L=@L+1 end
                                else                  begin set @status='W' set @W=@W+1 end
                        end
                end
 
                if @status<>' ' begin
                        insert into dbo.ResultTable (CardID, Status) values (@i, @status)
                        set @cards=0
                        set @hasace=0
                        set @sum=0
                        set @status=' '
                        set @NextCard = @i+1
                        if @i <= @LastPageCard set @LastCardOnPage = @i
                end
 
                set @i = @i+1
        end
 
        set @RS = @S
        set @RL = @L
        set @RW = @W
        set @RB = @B
 
END
go
 
-------------------------------------------------------------------------------------------
-- Use a WorkerQueue to manage parallel work
-------------------------------------------------------------------------------------------
 
-- status:
-- 0 not ready
-- 1 runnable
-- 2 running
-- 3 finished
if object_id('dbo.WorkQueue') is not null drop table dbo.WorkQueue
go
create table dbo.WorkQueue (
        id            int not null identity(0,1),
        status        int not null,
        block         int not null,
        firstcard     int not null,
        lastcard      int not null,
        lastpagecard  int not null,
        constraint PK_WorkQueue primary key clustered (id)
)
go
 
-- Tabell för loggning av vad som händer medan jobben kör
if object_id('dbo.applog') is not null drop table dbo.applog
go
create table dbo.applog (
        spid int,
        block int constraint PK_applog primary key clustered,
        t1 datetime2(3),
        t2 datetime2(3),
        t3 datetime2(3),
        t4 datetime2(3),
        t5 datetime2(3),
        firstcard int,
        lastcard int
)
go
 
-- Tabell för handskakning mellan de olika blocken
if object_id('dbo.Handshake') is not null drop table dbo.Handshake
go
create table dbo.Handshake (
        Block int not null PRIMARY KEY,
        NextCard int not null,
        S int not null,
        L int not null,
        W int not null,
        B int not null,
        dt datetime2(3) not null default (getdate())
)
go
 
if object_id('dbo.ProcessBlock') is not null drop procedure dbo.ProcessBlock
go
-- Processa ett block med kort
-- Anropas från en Worker
create procedure dbo.ProcessBlock(@BlockNumber int, @FirstCard int, @LastCard int, @LastPageCard int)
as
        declare @t1 datetime2(3)
        declare @t2 datetime2(3)
        declare @t3 datetime2(3)
        declare @t4 datetime2(3)
        declare @t5 datetime2(3)
 
        set @t1 = getdate()
 
        declare @MyLock   nvarchar(255) = cast(@BlockNumber as nvarchar(255))
        declare @PrevLock nvarchar(255) = cast(@BlockNumber-1 as nvarchar(255))
 
        -- Make sure that the next worker waits until we have processed cards in this block
        exec sp_getapplock @MyLock, 'Exclusive', 'Session'
 
        -- Start next worker
        update dbo.WorkQueue set status=1 where id = @BlockNumber+1
 
        declare @Input dbo.InputType
 
        -- Read a block of data from CardHistory to an in-memory table variable
        insert into @Input (CardID, Rank)
        select CardID, Rank
        from dbo.CardHistory
        where CardID >= @FirstCard and CardID <= @LastCard
 
        set @t2=getdate()
 
        declare @RealFirstCard int = 1
        declare @S int = 0
        declare @L int = 0
        declare @W int = 0
        declare @B int = 0
 
        if @BlockNumber > 0
        begin
                -- Wait for previous block
                exec sp_getapplock @PrevLock, 'Exclusive', 'Session'
                -- There is no reason to hold on to the lock once we got it
                exec sp_releaseapplock @PrevLock, 'Session'
 
                -- Read information from previous block
                select
                        @RealFirstCard = NextCard,
                        @S = S,
                        @L = L,
                        @W = W,
                        @B = B
                from dbo.Handshake where Block=@BlockNumber-1
        end
 
        set @t3=getdate()
 
        -- Process cards
        declare @NextCard int
        declare @LastCardOnPage int
 
        exec dbo.ProcessCards @Input, @RealFirstCard, @LastCard, @LastPageCard, @S output, @L output, @W output, @B output, @NextCard output, @LastCardOnPage output
 
        set @t4=getdate()
 
        -- Update handshake table
        insert into dbo.Handshake (Block, NextCard, S, L, W, B)
        values (@BlockNumber, @NextCard, @S, @L, @W, @B)
 
        -- signal to next block
        exec sp_releaseapplock @MyLock, 'Session'
 
        -- Update result
        -- First update all but the last row on the page
        -- Then update the last row in a separate statement
        -- This is done because SQL server will lock the next page if we include the last row in a range-based update
        begin tran
 
        update target
        set Status = t.Status
        from dbo.CardHistory target with(paglock)
        join dbo.ResultTable t with (snapshot) on t.CardID = target.CardID
        where target.CardID >= @FirstCard and target.CardID < @LastCardOnPage
 
        update target
        set Status = t.Status
        from dbo.CardHistory target with(paglock)
        join dbo.ResultTable t with (snapshot) on t.CardID = target.CardID
        where target.CardID = @LastCardOnPage
 
        commit tran with (delayed_durability=on)
 
        set @t5=getdate()
 
        -- Log timing information for this block
        insert into applog (block, spid, t1,t2,t3,t4,t5, firstcard, lastcard)
                values (@BlockNumber, @@SPID, @t1, @t2, @t3, @t4, @t5, @FirstCard, @LastCardOnPage)
 
go
 
if object_id('dbo.Worker') is not null drop procedure dbo.Worker
go
-- Each worker gets its work from the WorkQueue
-- The worker is terminated when all work is done
create procedure dbo.Worker
as
        set nocount on
 
        declare @jobid int = null
 
        while 1=1
        begin
                set @jobid = null
                while @jobid is null
                begin
 
                        begin tran
 
                                set @jobid = (
                                        select min(id)
                                        from dbo.WorkQueue with (tablockx, holdlock)
                                        where status=1
                                )
 
                                update dbo.WorkQueue set status=2 where id=@jobid
 
                        commit
 
                        if @jobid is null begin
                                -- Kolla om det finns jobb som inte är klara ännu
                                if exists(select * from dbo.WorkQueue) and not exists(select * from dbo.WorkQueue where status<3) begin
                                        -- Det finns jobb, men inget som inte är klart
                                        -- Avsluta proceduren
                                        return
                                end
                       
                                -- Det fanns inga tillgängliga jobb just nu, men det finns jobb som kommer att bli tillgängliga
                                -- Vänta en kort stund och försök igen
                                waitfor delay '00:00:00.010'
                        end
                end
 
                -- Do work
                declare @block         int
                declare @firstcard     int
                declare @lastcard      int
                declare @lastpagecard  int
                select
                        @block        = block,
                        @firstcard    = firstcard,
                        @lastcard     = lastcard,
                        @lastpagecard = lastpagecard
                from dbo.WorkQueue
                where id = @jobid
 
                exec ProcessBlock @block, @firstcard, @lastcard, @lastpagecard
 
                -- Mark work as finished
                update dbo.WorkQueue set status=3 where id=@jobid
 
        end
go
 
if object_id('dbo.StartWork') is not null drop procedure dbo.StartWork
go
-- Make the first Work available for pickup by a worker
create procedure dbo.StartWork
as
        set nocount on
        update dbo.WorkQueue set status=1 where id=0
go
 
if object_id('dbo.EndWork') is not null drop procedure dbo.EndWork
go
create procedure dbo.EndWork
as
        set nocount on
 
        -- Starta en egen worker som kommer att avslutas när det inte finns mer att göra
        -- Visa därefter högsta och minsta tiden i applog
        exec dbo.Worker
 
        declare @S int
        declare @L int
        declare @W int
        declare @B int
        select top 1
                @S = S,
                @L = L,
                @W = W,
                @B = B
        from dbo.Handshake
        order by Block desc
 
        truncate table dbo.DealerStatus
 
        insert into dbo.DealerStatus (Status, Deals)
        select 'S', @S union all
        select 'L', @L union all
        select 'W', @W union all
        select 'B', @B
 
        --
        -- Display statistics for this run
        --
        declare @t0 datetime2(3) = (select min(t1) from dbo.applog)
        declare @f float = 50
        select
                block,
                spid,
                --firstcard,
                --lastcard,
                --lastcard - firstcard + 1 as cards,
                datediff(ms, lag(t4, 1, null) over (order by block), t3) as d_ms,
                datediff(ms, t1, t2) as t1_ms,
                --datediff(ms, t2, t3) as t2_ms,
                datediff(ms, t3, t4) as t3_ms,
                datediff(ms, t4, t5) as t4_ms,
                [.........1.........2.........3.........4.........5.........6.........7.........8.........9.........0] =
                cast(
                replicate('.', datediff(ms, @t0, t1)/@f)+
                replicate('1', floor(datediff(ms, @t0, t2)/@f)-floor(datediff(ms, @t0, t1)/@f))+
                replicate('-', floor(datediff(ms, @t0, t3)/@f)-floor(datediff(ms, @t0, t2)/@f))+
                replicate('3', floor(datediff(ms, @t0, t4)/@f)-floor(datediff(ms, @t0, t3)/@f))+
                replicate('4', floor(datediff(ms, @t0, t5)/@f)-floor(datediff(ms, @t0, t4)/@f))+
                ''
                as varchar(300))
        from applog
        order by block
 
        select datediff(ms, min(t1), max(t5)) as ms from applog
 
        --select * from dbo.Handshake
 
        --select * from dbo.DealerStatus
go
if object_id('dbo.EndWork2') is not null drop procedure dbo.EndWork2
go
-- Starta en worker som väntar tills allt jobb är klart
-- Uppdatera DealerStatus med hjälp av innehållet i Handshake-tabellen
create procedure dbo.EndWork2
as
        set nocount on
 
        exec dbo.Worker
 
        declare @S int
        declare @L int
        declare @W int
        declare @B int
        select top 1
                @S = S,
                @L = L,
                @W = W,
                @B = B
        from dbo.Handshake
        order by Block desc
 
        truncate table dbo.DealerStatus
 
        insert into dbo.DealerStatus (Status, Deals)
        select 'S', @S union all
        select 'L', @L union all
        select 'W', @W union all
        select 'B', @B
go
 
if object_id('dbo.PrepareWork') is not null drop procedure dbo.PrepareWork
go
-- Dela in hela datamängden i block
-- lägg en rad i workqueue för varje block
-- Blockstorlek skall vara ett antal hela pages
create procedure dbo.PrepareWork(@BlockCount int = null)
as
 
        set nocount on
 
        delete from dbo.ResultTable
        delete from dbo.applog
        delete from dbo.Handshake
 
        truncate table dbo.WorkQueue
 
        set nocount on
 
        -- För maximal concurrency vill vi använda page locks vid uppdatering av dbo.CardHistory
        -- Vi tilldelar därför varje worker ett helt antal pages.
        -- Varje page rymmer (8192-96)/(9+7) = 506 rader
 
        declare @MaxCardID int = (select max(CardID) from dbo.CardHistory) -- rows in table
        declare @PageCount int = (@MaxCardID+506-1)/506                    -- Total number of pages in table
        -- Om blockcount inte är angiven räknar vi ut en blockcount som är experimentellt optimal
        if @BlockCount is null set @BlockCount = sqrt(@MaxCardID)/110
        declare @BlockSize int = (@PageCount+@BlockCount-1)/@BlockCount    -- in pages
        if @BlockSize > 5000 set @BlockSize = 5000                         -- More than 5000 pages per block triggers lock escalation
        if @BlockSize < 280 set @BlockSize = 280                           -- Blocks mindre än 280 pages är för små
        set @BlockSize = @BlockSize*506                                    -- Blocksize in rows
        declare @Block int = 0
 
        begin tran
 
        while @Block*@BlockSize+1 <= @MaxCardID
        begin
                -- +20 so the blocks overlap enough so the last card in one block is always also in the next block
                declare @LastCard int = (@Block+1)*@BlockSize+20
                if @LastCard > @MaxCardID set @LastCard = @MaxCardID
 
                insert into WorkQueue with (tablockx, holdlock)
                        (status, block, firstcard, lastcard, lastpagecard) values (0, @Block, @Block*@BlockSize+1, @LastCard, (@Block+1)*@BlockSize)
 
                set @Block += 1
        end
 
        commit
 
go
 
-------------------------------------------------------------------------------------------
-- Use Broker to create parallel workers
-------------------------------------------------------------------------------------------
 
if exists(select * from sys.services where name='TargetService') drop service TargetService
if exists(select * from sys.services where name='InitiatorService') drop service InitiatorService
if exists(select * from sys.service_contracts where name='MyContract') drop contract MyContract
if exists(select * from sys.service_message_types where name='StartWorkerMessage') drop message type StartWorkerMessage
create message type StartWorkerMessage
 
create contract MyContract
(
  StartWorkerMessage sent by initiator
);
 
if object_id('dbo.TargetQueue') is not null drop queue dbo.TargetQueue
if object_id('dbo.InitiatorQueue') is not null drop queue dbo.InitiatorQueue
 
create queue dbo.TargetQueue;
create service TargetService on queue dbo.TargetQueue (MyContract);
 
create queue dbo.InitiatorQueue;
create service InitiatorService on queue dbo.InitiatorQueue;
 
go
 
if object_id('dbo.TargetQueue_Procedure') is not null drop procedure dbo.TargetQueue_Procedure
go
-- Target procedure for service broker queue
create procedure dbo.TargetQueue_Procedure
as
begin
        set nocount on;
 
        declare @dh uniqueidentifier;
        declare @MsgType sysname;
 
        while 1 = 1
        begin
                -- Get one message
                waitfor
                (
                        receive top(1) @dh = conversation_handle,
                                                        @MsgType = message_type_name
                        from dbo.TargetQueue
                ), timeout 1000;
 
                -- Exit on timeout
                if @@rowcount = 0 break;
 
                if @MsgType = N'StartWorkerMessage'
                begin
                        exec dbo.Worker;
                end
                -- After the work is finished we end the conversation
                end conversation @dh;
        end
end;
go
 
if object_id('dbo.InitiatorQueue_Procedure') is not null drop procedure dbo.InitiatorQueue_Procedure
go
-- The purpose of this procedure is to end the conversation when receiving EndDialog messages from target
-- To avoid leaking enpoints conversations should always be closed by the receiver - not the sender
create procedure dbo.InitiatorQueue_Procedure
as
begin
        set nocount on;
 
        declare @dh uniqueidentifier;
        declare @MsgType sysname;
 
        while 1 = 1
        begin
                -- Get one message
                waitfor
                (
                        receive top(1) @dh = conversation_handle,
                                                        @MsgType = message_type_name
                        from dbo.InitiatorQueue
                ), timeout 1000;
 
                -- Exit on timeout
                if @@rowcount = 0 break;
 
                -- Just respond to any messages by ending the conversation
                end conversation @dh;
        end
end;
go
 
-- Make sure that the dbo.InitiatorQueue_Procedure is used as the activation procedure for the InitiatorQueue
alter queue InitiatorQueue with activation
(
        status = on,
        procedure_name = dbo.InitiatorQueue_Procedure,
        max_queue_readers = 1,
        execute as owner
)
go
 
if object_id('dbo.StartBrokerWorkers') is not null drop procedure dbo.StartBrokerWorkers
go
-- Start the specified number of workers by inserting messages in the TargetQueue
-- and then waiting until the queue monitor fires up a new worker
create procedure dbo.StartBrokerWorkers(@WorkerCount int)
as
begin
        declare @sql varchar(max) = '
        alter queue TargetQueue with activation
        (
                status = on,
                procedure_name = dbo.TargetQueue_Procedure,
                max_queue_readers = %1,
                execute as owner
        )
        '
        set @sql = replace(@sql , '%1', cast(@WorkerCount as varchar(10)))
        exec(@sql)
 
        truncate table dbo.WorkQueue
 
        declare @DlgHandle uniqueidentifier;
 
        while @WorkerCount > 0
        begin
                begin dialog @DlgHandle
                from service InitiatorService
                to service 'TargetService'
                on contract MyContract
                with encryption = off;
 
                send on conversation @DlgHandle message type StartWorkerMessage;
 
                -- Wait for queue monitor to start new thread
                waitfor delay '00:00:06'
 
                set @WorkerCount = @WorkerCount-1
        end
end
go
 
----------------------------------------------------------
-- End broker functions
----------------------------------------------------------
 
-- Start the script from here to run again
 
-- Make sure that ResultTable is empty
delete from dbo.ResultTable
 
-- Start background workers
exec StartBrokerWorkers 4
-- Display the started workers
select * from sys.dm_broker_activated_tasks
-- Perform a checkpoint now to avoid checkpoints during the test
checkpoint
 
--
-- Pipeline_5, Execute
--
-- Stefan Gustafsson, Acando
 
exec PrepareWork
exec StartWork
exec EndWork
 
/*
Result with @Shuffels=5000:
 
block       spid        d_ms        t1_ms       t3_ms       t4_ms       .........1.........2.........3
----------- ----------- ----------- ----------- ----------- ----------- ------------------------------
0           45          NULL        70          90          120         13344
1           44          0           77          70          147         11-3444
2           15          3           93          90          170         .11-33444
3           53          0           73          100         190         ..1---334444
4           42          4           70          93          190         ..11----334444
5           45          0           123         90          223         ......111-334444
6           44          0           120         97          223         .........11-334444
7           15          0           100         103         243         ...........11-3344444
8           53          3           116         134         193         .............111334444
9           42          3           107         133         150         ...............11--33444
10          45          0           113         100         144         ..................11-33444
11          44          0           114         90          140         ....................11-33444
12          15          0           97          87          137         ......................11-3344
 
ms
-----------
1497
 
*/