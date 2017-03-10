declare @c cursor,
		@c2 cursor,
		@key_id int,
		@key_name sysname,
		@parent_table_name sysname,
		@referenced_table_name sysname,
		@is_disabled bit,
		@is_not_for_replication bit,
		@delete_referential_action_desc nvarchar(60),
		@update_referential_action_desc nvarchar(60),
		@sql nvarchar(max)
	
declare	@column_list nvarchar(max),
		@column_list2 nvarchar(max),
		@text nvarchar(max),
		@text2 nvarchar(max)


set @c = cursor for

select	f.object_id,
		'[' +schema_name(o.schema_id)+'].[' + o.name + ']' as parent_table_name,
		'['+f.name+']' as key_name,
		'[' +schema_name(o2.schema_id)+'].[' + o2.name + ']' as referenced_table_name,
		f.is_disabled,
		f.is_not_for_replication,
		f.delete_referential_action_desc,
		f.update_referential_action_desc
	
from	sys.foreign_keys f
join	sys.objects o
on		f.parent_object_id = o.object_id
join	sys.objects o2
on		f.referenced_object_id = o2.object_id
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

open @c

fetch next from @c into @key_id, @parent_table_name, @key_name, @referenced_table_name, @is_disabled, @is_not_for_replication,  @delete_referential_action_desc, @update_referential_action_desc
while @@fetch_status=0
begin
	set @column_list = ''
	set @column_list2 = ''


	set @c2 = cursor for
	
	select		'['+c.name+']' as definition,
				'['+c2.name+']' as definition2
	from		sys.foreign_key_columns fc
	join		sys.columns c
	on			fc.parent_object_id = c.object_id
	and			fc.parent_column_id = c.column_id
	join		sys.columns c2
	on			fc.referenced_object_id = c2.object_id
	and			fc.referenced_column_id = c2.column_id
	where		fc.constraint_object_id =@key_id
	order by	fc.constraint_column_id


	open @c2
	
	fetch next from @c2 into @text, @text2
	while @@fetch_status=0
	begin
		if len(@column_list) >0
			set @column_list = @column_list+', '
		
		set @column_list = @column_list + @text
		
		if len(@column_list2) >0
			set @column_list2 = @column_list2+', '
		
		set @column_list2 = @column_list2 + @text2

		fetch next from @c2 into @text, @text2
		
	end
	
	set @sql = 'ALTER TABLE ' + @parent_table_name 

	if @is_disabled = 1
		set @sql = @sql + ' WITH NOCHECK'
	else
		set @sql = @sql + ' WITH CHECK'

	set @sql = @sql + ' ADD CONSTRAINT ' + @key_name + ' FOREIGN KEY (' +@column_list+ ') REFERENCES '+@referenced_table_name+' ('+ @column_list2 + ')'

	if @delete_referential_action_desc<> 'NO_ACTION'
		set @sql = @sql + ' ON DELETE ' + @delete_referential_action_desc

	if @update_referential_action_desc<> 'NO_ACTION'
		set @sql = @sql +  ' ON UPDATE ' + @update_referential_action_desc

	if @is_not_for_replication=1
		set @sql = @sql + ' NOT FOR REPLICATION'

	insert into #sql(sql) values(@sql)

	close @c2
	deallocate @c2

	fetch next from @c into @key_id, @parent_table_name, @key_name, @referenced_table_name, @is_disabled, @is_not_for_replication,  @delete_referential_action_desc, @update_referential_action_desc
end

close @c
deallocate @c