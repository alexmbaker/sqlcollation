declare @c1 cursor,
		@c2 cursor,
		@stats_id int,
		@object_id int,
		@schema_id int,
		@stats_name sysname,
		@object_name sysname,
		@no_recompute bit,
		@column_list nvarchar(max),
		@sql nvarchar(max)

set @c1 = cursor for
select	s.object_id,
		o.schema_id,
		s.stats_id,
		o.name,
		s.name,
		s.no_recompute
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
ORDER BY
	o.name, s.name

open @c1
fetch next from @c1 into @object_id,@schema_id, @stats_id, @object_name, @stats_name, @no_recompute
while @@fetch_status=0
begin

	set @column_list = ''

	set @c2 = cursor for
	
	select		'['+c.name+']' as definition
	from		sys.stats_columns sc
	join		sys.columns c
	on			sc.object_id = c.object_id
	and			sc.column_id = c.column_id
	where		sc.object_id =@object_id
	and			sc.stats_id = @stats_id
	order by	sc.stats_column_id

	open @c2
	
	fetch next from @c2 into @sql
	while @@fetch_status=0
	begin
		if len(@column_list) >0
			set @column_list = @column_list+', '
		
		set @column_list = @column_list +@sql
		

		fetch next from @c2 into @sql 
		
	end

	close @c2
	deallocate @c2

	set @sql = 'CREATE STATISTICS ['+@stats_name+'] ON [' + SCHEMA_NAME(@schema_id) + '].['+@object_name +'] ('+@column_list+')'
	if @no_recompute=1
		set @sql = @sql + ' WITH NORECOMPUTE'

	insert into #sql(sql) values(@sql)

	fetch next from @c1 into @object_id,@schema_id, @stats_id, @object_name, @stats_name, @no_recompute
end
close @c1
deallocate @c1
