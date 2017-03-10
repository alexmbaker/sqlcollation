--script out recreation of calculated columns
	
insert into #sql
select 'ALTER TABLE ['+u.name+'].['+o.name+'] ADD ['+c.name+'] AS '+sc.text 
from 	syscolumns c
join 	syscomments sc
on	c.id = sc.id
and	c.colid = sc.number
join	sysobjects o
on	o.id = c.id
join	sysusers u
on	o.uid = u.uid
where 	c.iscomputed=1 
and 	objectproperty(c.id,'IsMSShipped')=0 
and 	objectproperty(c.id,'IsTable')=1 

