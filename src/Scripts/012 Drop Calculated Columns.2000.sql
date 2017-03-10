/*drop calculated columns*/


	
insert into #sql (sql)
select 'ALTER TABLE ['+ u.name + '].['+o.name+'] drop column ['+c.name+']'
from 	syscolumns c
join	sysobjects o
on	c.id = o.id
join	sysusers u
on	u.uid = o.uid
where 	c.iscomputed=1 
and 	objectproperty(c.id,'IsMSShipped')=0 
and 	objectproperty(c.id,'IsTable')=1