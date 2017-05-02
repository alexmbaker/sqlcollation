--
-- Audit PKs and unique indexes for collisions due to the collation change
--


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
		@filter_definition nvarchar(2048)




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
and		(i.is_primary_key <> 0 OR i.is_unique <> 0 OR i.is_unique_constraint <> 0)
ORDER BY
	o.name, i.name

open @c
fetch next from @c into @object_id, @index_id, @index_name, @schema_name, @table_name, @type, @type_desc, @is_unique, @data_space_name, @ignore_dup_key, @is_primary_key, @is_unique_constraint, @fill_factor, @is_padded, @is_disabled, @is_hypothetical, @allow_row_locks, @allow_page_locks, @secondary_type_desc, @using_xml_index, @filter_definition

while @@fetch_status=0
begin
	--build up a column list 
	set @column_list = ''

	set @c2 = cursor for	
	select		'['+c.name+']' + CASE 
					WHEN c.system_type_id IN (SELECT DISTINCT system_type_id FROM sys.types WHERE collation_name IS NOT NULL) THEN ' COLLATE {1}'
					ELSE ''
				END as definition
	from		sys.index_columns ic
	join		sys.columns c
	on			ic.object_id = c.object_id
	and			ic.column_id = c.column_id
	where		ic.object_id = @object_id
	and			ic.index_id = @index_id
	and			is_included_column = 0
	order by	ic.key_ordinal

	open @c2
	
	fetch next from @c2 into @text
	while @@fetch_status=0
	begin
		if len(@column_list) >0
			set @column_list = @column_list+', '
		set @column_list = @column_list +@text

		fetch next from @c2 into @text
	end

	close @c2
	deallocate @c2

	set @text = '/* AUDIT PK/unique index ' + @table_name + '.' + @index_name + ' for collisions */ ' +
			'IF EXISTS(SELECT 1 FROM ['+@schema_name+'].[' + @table_name + ']'

	if len(@filter_definition) > 0
		set @text = @text + ' WHERE '+@filter_definition

	set @text = @text + ' GROUP BY '+@column_list+ ' HAVING COUNT(*) > 1) ' +
			'RAISERROR(''Table [' + @table_name + '] has data that is "different" under the current collation but will be considered the same after the collation change. PK/unique index ['
			+ @index_name + '] cannot be recreated under the new collation due to these collisions - the duplicate data should be fixed before making the collation change.'', 16, 1) WITH NOWAIT;'


	insert into #sql (sql) values (@text)
	
	fetch next from @c into @object_id, @index_id, @index_name, @schema_name, @table_name, @type, @type_desc, @is_unique, @data_space_name, @ignore_dup_key, @is_primary_key, @is_unique_constraint, @fill_factor, @is_padded, @is_disabled, @is_hypothetical, @allow_row_locks, @allow_page_locks, @secondary_type_desc, @using_xml_index, @filter_definition
end
close @c
deallocate @c



