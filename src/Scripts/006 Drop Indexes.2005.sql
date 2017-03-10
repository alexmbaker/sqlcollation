

--drop indexes
insert into #sql(sql)
select	case when is_primary_key=1 OR is_unique_constraint=1
		then 
			'ALTER TABLE ['+SCHEMA_NAME(o.schema_id)+'].['+o.name +'] DROP CONSTRAINT [' + i.name +']'
		else 
			'DROP INDEX [' + i.name +'] ON ['+SCHEMA_NAME(o.schema_id)+'].['+o.name +']' end
from	sys.indexes i
join	sys.objects o
on		i.object_id = o.object_id
where	(exists (
				--find any columns that have a collation specified
				select	1
				from	sys.index_columns ic
				join	sys.columns c
				on		ic.object_id = c.object_id
				and		ic.column_id = c.column_id
				where	collation_name is not null 
				and		c.object_id = i.object_id
				and		ic.index_id = i.index_id) 
				--{2} is the rebuild indexes option from application
				OR {2} = 1)
and		o.is_ms_shipped = 0
and		i.type <> 0 --dont care about heaps


