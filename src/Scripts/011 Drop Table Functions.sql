--drop Table Functions

insert into #sql (sql)
select 'DROP FUNCTION  ['+ u.name + '].['+o.name+']'
from 	sysobjects o
join	sysusers u
on	o.uid = u.uid
where 	objectproperty(id,'IsMSShipped')=0 
and 	objectproperty(id,'IsTableFunction')=1 