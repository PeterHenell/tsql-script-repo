IF OBJECT_ID('tempdb..#t_spinlock_stats') IS NOT NULL DROP TABLE #t_spinlock_stats;

CREATE table #t_spinlock_stats
(
    spinlockname VARCHAR(64), 
    collisions BIGINT,
    spins BIGINT, 
    [spins/collisions] BIGINT  ,
    [Sleep Time (ms)] BIGINT,
    Backoffs BIGINT)
 
insert into #t_spinlock_stats
exec ('dbcc sqlperf(spinlockstats)');
 
select * from #t_spinlock_stats order by collisions DESC

