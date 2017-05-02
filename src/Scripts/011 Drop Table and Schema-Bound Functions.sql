--drop Table Functions

insert into #sql (sql)
select 'DROP FUNCTION  ['+ SCHEMA_NAME(u.uid) + '].['+o.name+']'
from 	sysobjects o
join	sysusers u
on	o.uid = u.uid
where o.type = 'FN'
and objectproperty(o.id,'IsMSShipped')=0 
and
	(
		objectproperty(o.id,'IsTableFunction')=1
	OR
		objectproperty(o.id,'IsSchemaBound')=1
	)