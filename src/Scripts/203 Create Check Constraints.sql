insert into #sql (sql)
select 		'Alter table ['+u.name+'].[' + o.name + '] WITH NOCHECK ADD CONSTRAINT ['+object_name(cs.constid)+'] CHECK ' + CASE WHEN OBJECTPROPERTY ( cs.id , 'CnstIsNotRepl' )=1 then 'NOT FOR REPLICATION ' else '' end +  sc.text + '
' + case when objectproperty(cs.constid,'CnstIsDisabled') = 1 then 'Alter table ['+u.name+'].[' + o.name + '] NOCHECK CONSTRAINT ['+object_name(cs.constid)+']' else '' end
from 		sysconstraints cs
join 		syscomments sc
on		sc.id = cs.constid
join		sysobjects o
on		o.id = cs.id
join		sysusers u
on		u.uid = o.uid
where 	objectproperty(cs.constid,'IsCheckCnst') = 1 


