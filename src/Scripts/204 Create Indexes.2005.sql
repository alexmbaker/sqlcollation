
--select	case when is_primary_key=1 OR is_unique_constraint=1
--		then 
--			'ALTER TABLE ['+SCHEMA_NAME(o.schema_id)+'].['+o.name +'] DROP CONSTRAINT [' + i.name +']'
--		else 
--			'DROP INDEX [' + i.name +'] ON ['+SCHEMA_NAME(o.schema_id)+'].['+o.name +']' end
declare @c cursor,
		@c2 cursor,
		@object_id int,
		@index_id int,
		@index_name sysname,
		@schema_name sysname,
		@table_name sysname,
		@column_list nvarchar(max),
		@included_column_list nvarchar(max),
		@text nvarchar(max),
		@type tinyint,
		@type_desc nvarchar(60),
		@is_unique bit,
		@data_space_name sysname,
		@ignore_dup_key bit,
		@is_primary_key bit,
		@is_unique_constraint bit,
		@fill_factor tinyint,
		@is_padded bit,
		@is_disabled bit,
		@is_hypothetical bit,
		@allow_row_locks bit,
		@allow_page_locks bit,
		@secondary_type_desc nvarchar(60),
		@using_xml_index sysname,
		@is_included_column bit,
		@filter_definition nvarchar(max)




set @c = cursor for

select	i.object_id,
		i.index_id,
		i.name,
		SCHEMA_NAME(o.schema_id) as schema_name,
		o.name,
		i.type,
		i.type_desc,
		i.is_unique,
		d.name as data_space_name,
		i.ignore_dup_key,
		i.is_primary_key,
		i.is_unique_constraint,
		i.fill_factor,
		i.is_padded,
		i.is_disabled,
		i.is_hypothetical,
		i.allow_row_locks,
		i.allow_page_locks,
		x.secondary_type_desc,
		x2.name,
		i.filter_definition
from	sys.indexes i
join	sys.objects o
on		i.object_id = o.object_id
left join sys.xml_indexes x
on		x.object_id = i.object_id
and		x.index_id = i.index_id
left join sys.xml_indexes x2
on		x.object_id = i.object_id
and		x2.index_id = x.using_xml_index_id
join	sys.data_spaces d
on		d.data_space_id = i.data_space_id
where	(
			exists (
				--find any columns that have a collation specified
				select	1
				from	sys.index_columns ic
				join	sys.columns c
				on		ic.object_id = c.object_id
				and		ic.column_id = c.column_id
				where	collation_name is not null 
				and		c.object_id = i.object_id
				and		ic.index_id = i.index_id
			) 
		OR 
			--{2} is the rebuild indexes option from application
			{2} = 1
		OR
			-- statistics on it may be schema-bound
			i.has_filter <> 0
		)
and		o.is_ms_shipped = 0
and		(
			i.type <> 0 --dont care about heaps
		OR
			-- statistics on it may be schema-bound
			i.has_filter <> 0
		)
and		i.is_hypothetical = 0		-- do not recreate hypothetical indexes, Data Tuning Advisor should have dropped them
ORDER BY
	o.name, i.name


open @c
fetch next from @c into @object_id, @index_id, @index_name, @schema_name, @table_name, @type, @type_desc, @is_unique, @data_space_name, @ignore_dup_key, @is_primary_key, @is_unique_constraint, @fill_factor, @is_padded, @is_disabled, @is_hypothetical, @allow_row_locks, @allow_page_locks, @secondary_type_desc, @using_xml_index, @filter_definition

while @@fetch_status=0
begin
	--build up a column list 
	set @column_list = ''
	set @included_column_list = ''
	set @c2 = cursor for
	
	select		'['+c.name+']' + case when (@type in (1,2) and is_included_column=0) then case when ic.is_descending_key=1 then ' DESC' else ' ASC' end else '' end as definition,
				is_included_column
	from		sys.index_columns ic
	join		sys.columns c
	on			ic.object_id = c.object_id
	and			ic.column_id = c.column_id
	where		ic.object_id =@object_id
	and			ic.index_id = @index_id
	order by	ic.key_ordinal

	open @c2
	
	fetch next from @c2 into @text, @is_included_column
	while @@fetch_status=0
	begin
		if @is_included_column=1
		begin
			if len(@included_column_list) >0
				set @included_column_list = @included_column_list+', '
			set @included_column_list = @included_column_list +@text
		end
		else
		begin
			if len(@column_list) >0
				set @column_list = @column_list+', '
			set @column_list = @column_list +@text
		end

		fetch next from @c2 into @text , @is_included_column
		
	end

	close @c2
	deallocate @c2

	--now included columns 
	
	


	if @type = 3
	begin
		--XML index
		set @text = 'CREATE ' + case when @using_xml_index is null then 'PRIMARY ' else '' end
			+ 'XML INDEX ['+@index_name+'] ON ['+@schema_name+'].[' + @table_name + '] ('+@column_list+')'
		
		if @using_xml_index is not null
			set @text = @text + ' USING XML INDEX ['+@using_xml_index+'] FOR ' + @secondary_type_desc 

		set @text = @text +	' WITH ('

	end
	else
	begin

		--also when partitioned then need to get the partition column as well..
		
		if @is_primary_key=1
		begin
			set @text ='ALTER TABLE ['+@schema_name+'].[' + @table_name + '] WITH NOCHECK ADD CONSTRAINT ['
					+ @index_name + '] PRIMARY KEY ' + case when @type=1 then 'CLUSTERED' else 'NONCLUSTERED' end + 
					' ('+@column_list+')'
					
		end
		else
		begin
			if @is_unique_constraint = 1
			begin
				set @text ='ALTER TABLE ['+@schema_name+'].[' + @table_name + '] WITH NOCHECK ADD CONSTRAINT ['
						+ @index_name + '] UNIQUE ' + case when @type=1 then 'CLUSTERED' else 'NONCLUSTERED' end + 
						' ('+@column_list+')'				
			end
			else
			begin
				set @text ='CREATE '+ case when @is_unique=1 then 'UNIQUE ' else '' end 
						+ case when @type=1 then 'CLUSTERED' else 'NONCLUSTERED' end + ' INDEX ['
						+ @index_name + '] ON ['+@schema_name+'].[' + @table_name + '] ('+@column_list+')'
			end
			
					
		end
		
					

		if len(@included_column_list)>0
			set @text = @text + ' INCLUDE ('+@included_column_list+')'

		if len(@filter_definition)>0
			set @text = @text + ' WHERE '+@filter_definition+' '

		set @text = @text +	' WITH ('

		
		set @text = @text + 'IGNORE_DUP_KEY = ' + case when @ignore_dup_key=1 then 'ON' else 'OFF' end + ', '
		
		--only for enterprise edition - doesn't really matter
		--set @text = @text + ', ONLINE = ' + case when @is_disabled=1 then 'OFF' else 'ON' end +', '


		
	end
	--Common index options
	set @text = @text + 'PAD_INDEX = ' + case when @is_padded=1 then 'ON' else 'OFF' end
	
	if @fill_factor>0
		set @text = @text + ', FILLFACTOR =' + ltrim(str(@fill_factor))
		
	set @text = @text + ', STATISTICS_NORECOMPUTE = ' + case when (select no_recompute from sys.stats where object_id = @object_id and stats_id = @index_id ) = 1 then 'ON' else 'OFF' end
	set @text = @text + ', ALLOW_ROW_LOCKS = ' + case when @allow_row_locks=1 then 'ON' else 'OFF' end
	set @text = @text + ', ALLOW_PAGE_LOCKS = ' + case when @allow_page_locks=1 then 'ON' else 'OFF' end + ')'

	if @type <> 3
	
		set @text = @text + ' ON ['+@data_space_name+']'

	insert into #sql (sql) values (@text)
	
	fetch next from @c into @object_id, @index_id, @index_name, @schema_name, @table_name, @type, @type_desc, @is_unique, @data_space_name, @ignore_dup_key, @is_primary_key, @is_unique_constraint, @fill_factor, @is_padded, @is_disabled, @is_hypothetical, @allow_row_locks, @allow_page_locks, @secondary_type_desc, @using_xml_index, @filter_definition
end
close @c
deallocate @c



--select * from sys.xml_indexes

