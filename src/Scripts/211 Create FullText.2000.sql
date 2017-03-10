declare @table_cursor cursor,
		@table_owner sysname,
		@table_name sysname,
		@key_index_name sysname,
		@key_colid int,
		@index_active int,
		@catalog_name sysname,
		@result int,
		@qualified_table_name nvarchar(517)
		
declare @column_cursor cursor,
		@table_id int,
		@column_id int,
		@column_name sysname,
		@doc_type_column_name sysname,
		@doc_type_column_id int,
		@language int
		

if DatabaseProperty(db_name(), 'IsFulltextEnabled') <> 0
BEGIN

	exec sp_help_fulltext_tables_cursor @cursor_return  = @table_cursor OUTPUT

	fetch next from @table_cursor into @table_owner, @table_name, @key_index_name, @key_colid, @index_active, @catalog_name
	while @@fetch_status=0
	begin 
		set @qualified_table_name = '['+@table_owner+'].['+@table_name+']'
		insert into #sql (sql) 
		select 'exec sp_fulltext_table @tabname ='''+@qualified_table_name+''', @action=''create'',@ftcat='''+@catalog_name+''', @keyname='''+@key_index_name+'''' 
		
		exec sp_help_fulltext_columns_cursor @cursor_return  = @column_cursor OUTPUT, @table_name = @qualified_table_name
		fetch next from @column_cursor into @table_owner, @table_id, @table_name,@column_name, @column_id,  @doc_type_column_name, @doc_type_column_id, @language
		while @@fetch_status=0
		begin
			--override according to user selection in the UI
			if {3} <> -2147483648
				set @language = {3}

			insert into #sql (sql) 
			select 'exec sp_fulltext_column @tabname ='''+@qualified_table_name+''',@colname='''+@column_name+''',  @action=''add'',@language ='+cast(@language as varchar(10))+', @type_colname='+case when @doc_type_column_name is null then 'NULL' else '''' +@doc_type_column_name+ '''' end 
			fetch next from @column_cursor into @table_owner, @table_id, @table_name,@column_name, @column_id,  @doc_type_column_name, @doc_type_column_id, @language		
		end
		close @column_cursor
		deallocate @column_cursor
				
		fetch next from @table_cursor into @table_owner, @table_name, @key_index_name, @key_colid, @index_active, @catalog_name
	end
	close @table_cursor
	deallocate @table_cursor


END
