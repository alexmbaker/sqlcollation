/*script out dropping of check constraints */
insert into #sql (sql)
select 	'Alter table ['+ u.name + '].['+o.name+'] drop constraint ['+object_name(cs.constid)+']'
from 	sysconstraints cs
join	sysobjects o
on	cs.id = o.id
join	sysusers u
on	u.uid = o.uid
where 	objectproperty(cs.constid,'IsCheckCnst') = 1