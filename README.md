# ParseCronString
The intention of the project is to have a scheduler using the cron format to schedule. 
Have started with MSSQL version. Will extend few other languages. 

You are all invited to contribute by development / testing / reviewing

Simple eg 1 in MSSQL -> select dbo.getNextRunTimeFromCron('2017-03-16 10:40:00', '* * * * * *')

Every Minute

Simple eg 2 in MSSQL -> select dbo.getNextRunTimeFromCron('2017-03-16 10:40:00', '30 9 * * * *')

Every day at 09:30


Complex eg in MSSQL -> select dbo.getNextRunTimeFromCron('2017-03-16 10:40:00', '0 10/12 5-10 1,5,6 *')

At minute 0 past every 12th hour from 10:00 through 23:00 on every day-of-month from 5 through 10 in January, May, and June.
