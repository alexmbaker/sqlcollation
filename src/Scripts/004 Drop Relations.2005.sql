--work out which indexes will be dropped - we do this then work out which constrainst need to be dropped as 
--some constratins are dependant on primary keys


--drop foreign keys
insert into #sql(sql)
select 'ALTER TABLE ['+SCHEMA_NAME(o.schema_id)+'].['+o.name +'] DROP CONSTRAINT ['+f.name+']'
from	sys.foreign_keys f
join	sys.objects o
on		f.parent_object_id = o.object_id
where	(f.object_id in (
				--find any columns that have a collation specified
				select	kc.constraint_object_id
				from	sys.foreign_key_columns kc
				join	sys.columns c
				on		kc.parent_object_id = c.object_id
				and		kc.parent_column_id = c.column_id
				where	collation_name is not null 

				UNION ALL
				--probably don't need both bits as relationships can not be created 
				--on columns of different types
				select	kc.constraint_object_id
				from	sys.foreign_key_columns kc
				join	sys.columns c
				on		kc.referenced_object_id = c.object_id
				and		kc.referenced_column_id = c.column_id
				where	collation_name is not null 
				) 
				--{2} is the rebuild indexes option from application
				OR {2} = 1)
and		o.is_ms_shipped = 0
ORDER BY	o.name, f.name
