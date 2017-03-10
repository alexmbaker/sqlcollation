--script out recreation of calculated columns
	
insert into #sql

select		'ALTER TABLE ['+u.name+'].['+o.name+'] ADD ['+c.name+'] AS '+c.definition + case when c.is_persisted =1 then ' PERSISTED' else '' end + case when c.is_nullable = 0 then ' NOT NULL ' else '' end
from 		sys.computed_columns c
join		sys.objects o
on			c.object_id = o.object_id
join		sys.schemas u
on			u.schema_id = o.schema_id
where 		o.type ='U'
and			objectproperty(o.object_id,'IsMSShipped')=0
and 		objectproperty(c.object_id,'IsTable')=1


