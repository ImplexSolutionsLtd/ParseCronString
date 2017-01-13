CREATE Function getNextRunTimeFromCron(@lastRunTime datetime, @cronString  varchar(100))
returns datetime
as
Begin
	Declare @CoreTable Table(Idx int, data int)
	Declare @ValidDays Table(dt date Primary key, isValid bit default 0)
	Declare @ValidHours Table (hr int, mins int)
	Declare @dt dateTime
	;
	 --select 1, 'Minute' Union all
	 --select 2, 'Hour' Union all
	 --select 3, 'DayOfMonth' Union all
	 --select 4, 'MonthOfYear' Union all
	 --select 5, 'DayOfWeek' Union all
	 --select 6, 'Year' 

	With ElementLimits as
	(
	  Select 1 idx, 0 StartValue, 59 endValue Union all 
	  Select 2 idx, 0 StartValue, 23 endValue Union all 
	  Select 3 idx, 1 StartValue, 31 endValue Union all 
	  Select 4 idx, 1 StartValue, 12 endValue Union all 
	  Select 5 idx, 1 StartValue, 7 endValue Union all 
	  Select 6 idx, year(@lastRunTime) StartValue,  year(@lastRunTime) + 100 endValue 
	)
	,CoreTable as
	(
	select cron.idx, Row_Number() over(Partition by cron.idx order by cron.idx) rowid,  innerdata.splitdata data from dbo.fnSplitString(@cronString, ' ') cron
		CROSS APPLY dbo.fnSplitString(cron.splitdata, ',') innerdata
	)
	--select * from coreTable
	, rangedata as
	(
	select core.idx, max(case when split.idx=1 then splitdata else -1 end) startRange,  cast(max(case when split.idx=2 then splitdata else '-1' end)  as varchar(1000)) endRange  
	from CoreTable core
	Cross Apply dbo.fnSplitString(data, '-') split
	Where data like '%-%'
	group by core.idx, rowid
	)
	,rangedataExpanded as
	(
	   select idx, startRange data, endRange from rangedata 
	   Union all 
	   Select idx, data + case when charindex('/', endRange) != 0 then cast(substring(endRange, CHARINDEX('/', endrange) + 1, 1000) as int) else  1 end, endRange from rangedataExpanded 
			where data + case when charindex('/', endRange) != 0 then cast(substring(endRange, CHARINDEX('/', endrange) + 1, 1000) as int) else  1 end < cast(case when charindex('/', endRange) != 0 then substring(endRange, 1, CHARINDEX('/', endrange) - 1) else endRange end  as int)
	) 
	, CoreTable1 as
	(
		Select idx, data from coreTable where data not like '%-%' Union
		select idx, cast(data as varchar(250)) data from rangedataExpanded
	)
	--select * from CoreTable1
	,EveryTable as 
	(
		select ct.idx, Substring(data, 3, 1000) data, el.StartValue, el.endValue from CoreTable1  ct
			inner join ElementLimits el on ct.idx = el.idx
		where data like '%/%'	
	)
	,EveryTableExpanded as
	(
		select idx, StartValue value, endValue, data increment from EveryTable 
		union all 
		select idx, value + increment, endValue, increment from EveryTableExpanded
		where value + increment < endValue
	)
	--select * from EveryTableExpanded
	,CoreTable2 as
	(
	select idx, cast(value as varchar(100)) data from EveryTableExpanded
	Union all 
	select * from CoreTable1 where data not like '%/%'
	 )
	,CoreTable3 as
	 (
	 Select distinct idx, data from CoreTable2 where data = '*'
	 Union  all
	 Select * from CoreTable2 where idx not in ( Select distinct idx from CoreTable2 where data = '*')
	 )
	 ,FilterStar as
	 (
		 select ct.idx, el.StartValue, el.endValue from CoreTable3 ct
			inner join ElementLimits el on ct.idx = el.idx
		 where data = '*'
	 )
	 ,FilterStarExapanded as
	 (
		select idx, StartValue data, endValue from FilterStar
		Union all
		select idx, data + 1, endValue from FilterStarExapanded where data < endValue
	)
	,CoreTable4 as
	(
		select idx, data from FilterStarExapanded
		Union all
		Select idx, data from CoreTable3 where data != '*'
	)

		Insert into @CoreTable 
		Select idx, data from CoreTable4

		Insert into @ValidDays
		Select distinct datefromParts(yr.data, moy.data, dom.data) dt, 0	
		from @CoreTable yr
		Cross join @CoreTable moy
		Cross join @CoreTable dom
		Where dom.idx = 3 and moy.idx = 4 and yr.idx = 6
		and isdate(cast(yr.data as varchar(4)) + '-' + cast(moy.data as varchar(2))+ '-' + cast(dom.data as varchar(2))) = 1 
		and datefromParts(yr.data, moy.data, dom.data) >= cast(@lastRunTime as date)
	
		Insert into @ValidHours
		select hr.data, mins.data
		from
		@CoreTable hr
			Cross join @CoreTable mins
		where hr.idx = 2 and mins.idx = 1
	
	
		update vd set isValid = 1
			from @ValidDays vd
			Cross Join @CoreTable ct
			where ct.Idx = 5 and datepart(weekday, dt) = ct.data

	
		select  top 1 
		@dt = dateadd(Hour, vh.hr, dateadd(Minute, vh.mins, cast(vd.dt as datetime)))  from @ValidDays vd
			Cross join @ValidHours	 vh
		where isValid = 1
		and dateadd(Hour, vh.hr, dateadd(Minute, vh.mins, cast(vd.dt as datetime))) > @lastRunTime
		order by dt, hr, mins

		return @dt
End
