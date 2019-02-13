
declare @name sysname,
		@id int,
		@id_last int,
		@last sysname,
		@owner sysname,
		@test_text nvarchar(4000),
		@pos_create_fn int,
		@pos_comment_start int,
		@pos_comment_end int,
		@offset int,
		@pos_function_name int,
		@pos_object_name int,
		@c cursor,
		@sql_segment nvarchar(4000),
		@text_ptr binary(16),
		@ansi_nulls nvarchar(100)

set 	@id_last =0

set			@c = cursor for
select 		o.name as functionName, 
			o.id,
			sc.text,
			u.name,
			'SET ANSI_NULLS ' + case when OBJECTPROPERTY(o.id,'IsAnsiNullsOn') =1 then 'ON' else 'OFF' end as [AnsiNulls]
from		sysobjects o
join		syscomments sc
on			o.id = sc.id
join		sysusers u
on			u.uid = o.uid
where 	o.type in ('FN','TF')
and		objectproperty(o.id,'IsMSShipped')=0 
and
		(
			objectproperty(o.id,'IsTableFunction')=1
		OR
			objectproperty(o.id,'IsSchemaBound')=1
		)
order by	o.id, 
			sc.colid  



open @c
fetch next from @c into @name, @id, @sql_segment, @owner, @ansi_nulls
while @@Fetch_Status=0
begin
	if @id<>@id_last
	begin
		--add the ansi nulls setting
		insert into #sql (sql) values (@ansi_nulls)

		--add a row for our data
		insert into #sql (sql) values ('')
		
		--get a text pointer
		SELECT @text_ptr = TEXTPTR(sql) FROM #sql where id = (select max(id) from #sql)

		set @id_last =@id

		-- now look at the create function part of the sql, make sure that the owner
		-- name is specified

		set @pos_create_fn = patindex('%create%function%', @sql_segment)
		set @pos_comment_start = patindex('%/*%', @sql_segment)
		set @offset = 1
		set @test_text = @sql_segment
		-- it is possible that there are create function statments in comments at the
		-- start of the sql so look for the one that actually creates the function

		while @pos_comment_start <@pos_create_fn and @pos_comment_start<>0
		begin
			set @pos_comment_end = patindex('%*/%', @test_text)
			set @offset = @offset+@pos_comment_end+1
			set @test_text = substring(@sql_segment, @offset, len(@sql_segment) - @offset)
			set @pos_create_fn = patindex('%create%function%', @test_text collate latin1_general_ci_ai)
			set @pos_comment_start = patindex('%/*%', @test_text)
		end

		-- now look to see if the owner name is specified, there should be a
		-- . before the function name so inspect the text between the word function and the actual
		-- function name

		set @pos_function_name = charindex('function' collate latin1_general_ci_ai, @sql_segment collate latin1_general_ci_ai, @pos_create_fn-1+@offset)
		if @pos_function_name>0
			set @pos_function_name=@pos_function_name+8  --number of characters in the word function
		
		set @pos_object_name = charindex(@name collate latin1_general_ci_ai, @sql_segment collate latin1_general_ci_ai, @pos_function_name)
		
		set @test_text= substring(@sql_segment,@pos_function_name,@pos_object_name-@pos_function_name)
		
		if charindex('.',@test_text,1)=0
		begin
			-- the owner name is missing, add it
			declare @Tempsql nvarchar(4000),
					@adjust int
			set @Tempsql = left(@sql_segment, @pos_function_name) + '['+@owner+'].'
			UPDATETEXT #sql.sql @text_ptr NULL 0 @Tempsql
			
			if substring(@sql_segment, @pos_object_name-1, 1)='['
				set @adjust = -1
			else
				set @adjust = 0
				
			set @sql_segment = substring(@sql_segment, @pos_object_name + @adjust ,len(@sql_segment) -@pos_object_name +1+@adjust)

			
		end

	end
	
	UPDATETEXT #sql.sql @text_ptr NULL 0 @sql_segment

	fetch next from @c into @name, @id, @sql_segment, @owner, @ansi_nulls
end
Close @c
deallocate @c


-- now the permissions on the functions that have been recreated
insert into #sql (sql)
select 	case p.protecttype 
		when 206 then 'DENY ' 
		else 'GRANT ' end + 
	case p.action 
		when 193 then 'SELECT'
		when 26 then 'REFERENCES'
		end+
	' on ['+user_name(o.uid)+'].['+o.name+'] to ['+user_name(p.uid)+']' +
	case when p.protecttype = 204 then ' WITH GRANT OPTION' else '' end
from 	sysprotects p 
join 	sysobjects o
on	p.id = o.id
where 	o.type in ('FN','TF')
and		objectproperty(o.id,'IsMSShipped')=0 
and
		(
			objectproperty(o.id,'IsTableFunction')=1
		OR
			objectproperty(o.id,'IsSchemaBound')=1
		)

