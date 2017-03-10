/*drop calculated columns*/


	
insert into #sql (sql)
select		'ALTER TABLE ['+ u.name + '].['+o.name+'] drop column ['+c.name+']'
from 		sys.computed_columns c
join		sys.objects o
on			c.object_id = o.object_id
join		sys.schemas u
on			u.schema_id = o.schema_id
where 		o.type ='U'
and			objectproperty(o.object_id,'IsMSShipped')=0
and 		objectproperty(c.object_id,'IsTable')=1
