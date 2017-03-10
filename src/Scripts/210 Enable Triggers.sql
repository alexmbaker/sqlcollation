-- script out the enabling of triggers 
insert into #sql (sql)

select 'alter table ['+u2.name+'].[' + o2.name + '] enable trigger [' +o1.name+']'
from 	sysobjects o1
join 	sysobjects o2
on	o1.parent_obj = o2.id
join	sysusers u2
on	o2.uid = u2.uid
where 	o1.type = 'TR' 
and 	OBJECTPROPERTY(o1.id,'ExecIsTriggerDisabled')=0
and 	OBJECTPROPERTY(o2.id, 'IsTable')=1
