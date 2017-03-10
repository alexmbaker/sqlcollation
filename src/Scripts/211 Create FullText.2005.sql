--now recreate the full text indexes
declare @column_list nvarchar(max)
declare @object_id int
declare @table_name sysname, @catalog_name sysname, @key_index_name sysname, @change_tracking_state_desc nvarchar(60)

declare @column_sql nvarchar(max)
declare @fulltext_tables cursor 
declare @fulltext_columns cursor
declare @new_languageid int

--get a list of the indexes
set		@fulltext_tables = cursor for 
select	o.object_id,
		o.name as index_name,
		ki.name as key_index_name,
		c.name as catalog_name,
		i.change_tracking_state_desc
from	sys.fulltext_indexes i 
join	sys.objects o 
on		i.object_id = o.object_id
join	sys.indexes ki
on		ki.object_id = i.object_id
and		ki.index_id = i.unique_index_id
join	sys.fulltext_catalogs c
on		c.fulltext_catalog_id = i.fulltext_catalog_id

--NOTE:: can not find the property for CHANGE_TRACKING OFF, NO POPULATION

open @fulltext_tables
fetch next from @fulltext_tables into @object_id, @table_name , @key_index_name, @catalog_name, @change_tracking_state_desc
while @@fetch_status = 0
begin
	--build up a column list for involved columns
	set @column_list=''
	set  @fulltext_columns = cursor for 
	select		'['+c.name +']'+ 
					case when t.name is null then '' else ' TYPE COLUMN '+t.name end + 
					' LANGUAGE '
						+ cast( 
							--this bit reads the selected language id from the application 
							--if the value is -2147483648 then don't change the language
							(case when {3} = -2147483648 then language_id else {3} end) as varchar(5))
	from		sys.fulltext_index_columns ic
	join		sys.columns c
	on			c.object_id = ic.object_id
	and			c.column_id = ic.column_id
	left join	sys.types t
	on			ic.type_column_id = t.user_type_id
	where		ic.object_id = @object_id
	open @fulltext_columns
	
	fetch next from @fulltext_columns into @column_sql
	while @@FETCH_STATUS=0
	begin
		if len(@column_list) >0
			set @column_list = @column_list + ', '
		set @column_list = @column_list + @column_sql
		
		fetch next from @fulltext_columns into @column_sql
	end

	close @fulltext_columns
	deallocate @fulltext_columns

	insert into #sql (sql)	
	select 'CREATE FULLTEXT INDEX ON ['+@table_name+'] ('+@column_list+') KEY INDEX ['+@key_index_name+'] ON ['+@catalog_name+'] WITH CHANGE_TRACKING '+@change_tracking_state_desc
	fetch next from @fulltext_tables into @object_id, @table_name , @key_index_name, @catalog_name, @change_tracking_state_desc
end

close @fulltext_tables
deallocate @fulltext_tables