declare @table_cursor cursor
declare @table_owner sysname
declare @table_name sysname
declare @key_index_name sysname
declare @key_colid int
declare @index_active int
declare @catalog_name sysname
declare @result int

if DatabaseProperty(db_name(), 'IsFulltextEnabled') <> 0
BEGIN

	exec sp_help_fulltext_tables_cursor @cursor_return  = @table_cursor OUTPUT

	fetch next from @table_cursor into @table_owner, @table_name, @key_index_name, @key_colid, @index_active, @catalog_name
	while @@fetch_status=0
	begin 
		insert into #sql (sql) 
		select 'exec sp_fulltext_table @tabname =''['+@table_owner+'].['+@table_name+']'', @action=''drop'' ' 
		
		fetch next from @table_cursor into @table_owner, @table_name, @key_index_name, @key_colid, @index_active, @catalog_name
	end
	close @table_cursor
	deallocate @table_cursor


END

