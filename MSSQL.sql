Declare @lastRunTime datetime, @cronString  varchar(100)
select @lastRunTime = '2017-01-10 10:00:00', @cronString = '0 0 * * * *'

;
 --select 1, 'Minute' Union all
 --select 2, 'Hour' Union all
 --select 3, 'DayOfMonth' Union all
 --select 4, 'MonthOfYear' Union all
 --select 5, 'DayOfWeek' Union all
 --select 6, 'Year' 

With coreTable as
(
select cron.idx, innerdata.splitdata data from dbo.fnSplitString(@cronString, ' ') cron
	CROSS APPLY dbo.fnSplitString(cron.splitdata, ',') innerdata
)
, rangedata as
(
select core.idx, max(case when split.idx=1 then splitdata else -1 end) startRange,  max(case when split.idx=2 then splitdata else -1 end) endRange  
from coreTable core
Cross Apply dbo.fnSplitString(data, '-') split
Where data like '%-%'
Group by core.idx
)
,rangedataExpanded as
(
   select idx, startRange data, endRange from rangedata 
   Union all 
   Select idx, data + 1, endRange from rangedataExpanded where data < endRange
) 
, CoreTable1 as
(
	Select idx, data from coreTable where data not like '%-%' Union all
	select idx, cast(data as varchar(250)) data from rangedataExpanded
)
,CoreTable2 as
(
select idx, data from CoreTable1 where data not like '%/%'
Union all
select core.idx, cast(
case core.idx
	when 1 then DATEPART(MINUTE, @lastRunTime) + split.splitdata
	when 2 then DATEPART(HOUR, @lastRunTime) + split.splitdata
	when 3 then DATEPART(DAY, @lastRunTime) + split.splitdata
	when 4 then DATEPART(MONTH, @lastRunTime) + split.splitdata
	when 5 then DATEPART(WEEKDAY, @lastRunTime) + split.splitdata
	when 6 then DATEPART(YEAR, @lastRunTime) + split.splitdata
	else 0 end	as varchar(250))
from CoreTable1 core
	Cross Apply dbo.fnSplitString(data, '/') split
	where data like '%/%' and split.idx = 2
)
,dates as (
select
		case when a5.data is null or a5.data = '*' then null else a5.data end Wday,
		cast(
		cast(case when a6.data is null or a6.data = '*' then DatePart(YEAR, @lastRunTime) else a6.data end as varchar(50)) + '-' +
		cast(case when a4.data is null or a4.data = '*' then DatePart(Month, @lastRunTime) else a4.data end as varchar(50)) + '-' +
		cast(case when a3.data is null or a3.data = '*' then DatePart(Day, @LastRunTime) else a3.data end as varchar(50)) + ' ' +
		cast(case when a2.data is null or a2.data = '*' then DatePart(Hour, @LastRunTime) else a2.data end as varchar(50)) + ':' + 
		cast(case when a1.data is null or a1.data = '*' then DatePart(Minute, @LastRunTime) + 1 else a1.data end as varchar(50)) + ':00' as datetime) dt
 from 
		CoreTable2 a1 CROSS JOIN
		CoreTable2 a2 CROSS JOIN
		CoreTable2 a3 CROSS JOIN
		CoreTable2 a4 CROSS JOIN
		CoreTable2 a5 CROSS JOIN
		CoreTable2 a6 
Where a1.idx = 1 and a2.idx = 2 and a3.idx = 3 and a4.idx = 4 and a5.idx = 5 and a6.idx = 6
)
select *
from dates
where dt > getdate() and (Wday is null or DATEPART(WEEKDAY, dt) = Wday)
order by dt
