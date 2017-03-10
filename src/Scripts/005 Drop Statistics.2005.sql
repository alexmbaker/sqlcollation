
--drop statistics
insert into #sql(sql)
select	'DROP STATISTICS ['+SCHEMA_NAME(o.schema_id)+'].['+o.name +'].['+s.name+']'
from	sys.stats s
join	sys.objects o
on		s.object_id = o.object_id
where	(exists (
				--find any columns that have a collation specified
				select	c.object_id
				from	sys.stats_columns sc
				join	sys.columns c
				on		sc.object_id = c.object_id
				and		sc.column_id = c.column_id
				where	collation_name is not null
				and		sc.object_id = s.object_id
				and		sc.stats_id = s.stats_id
				) 
				--{2} is the rebuild indexes option from application
				OR {2} = 1)
and		o.is_ms_shipped = 0
and		s.user_created=1

