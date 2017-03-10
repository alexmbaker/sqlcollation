
declare @table_name sysname,
	@user_name sysname,
	@column_name sysname,
	@length nvarchar(100),
	@type_name sysname,
	@type_user_name sysname,
	@null_text nvarchar(100),
	@id int,
	@c cursor,
	@sql_segment nvarchar(4000),
	@is_user_type bit

set 	@c = cursor for 

select 		o.object_id,
			u.name,
			o.name as table_name, 
			c.name as column_name, 
			case when t2.name like 'n%' then cast(c.max_length / 2 as nvarchar(100)) else cast(c.max_length as nvarchar(100)) end as Length, 
			u2.name as type_user_name,
			t.name as type_name,
			--t2.name as base_type_name,
			case when c.is_nullable=1 then 'NULL' else 'NOT NULL' end as nullable,
			case when t.user_type_id = t.system_type_id then 0 else 1 end as is_user_type
from 		sys.objects o
join 		sys.columns c
on			o.object_id = c.object_id
join 		sys.types t
on			t.user_type_id = c.user_type_id
and			t.system_type_id = c.system_type_id
--when this is a user data type we need to qualify the type user name
join 		sys.schemas u2
on			u2.schema_id  = t.schema_id 
--get the base type when column is a user type
join		sys.types t2
on			t2.user_type_id = c.system_type_id
and			t2.system_type_id = c.system_type_id

join		sys.schemas u
on			u.schema_id = o.schema_id
where 		o.type ='U'
and			objectproperty(o.object_id,'IsMSShipped')=0
and 		c.collation_name is not null
and			c.is_computed=0
--and			c.collation_id <> 0

open @c



fetch next from @c into @id,@user_name,@table_name, @column_name, @length, @type_user_name, @type_name, @null_text, @is_user_type
while @@Fetch_Status = 0
begin
	set @sql_segment = 'Alter table ['+@user_name+'].['+@table_name COLLATE DATABASE_DEFAULT+'] Alter Column ['+@column_name COLLATE DATABASE_DEFAULT+ '] ['+ @type_user_name COLLATE DATABASE_DEFAULT +'].['+@type_name COLLATE DATABASE_DEFAULT+']' 

	if @is_user_type=0
	begin
		if @type_name COLLATE DATABASE_DEFAULT in ('nvarchar', 'varchar','char','nchar')
		begin
			--nvarchar max functionality for sql 2005
			if @length COLLATE DATABASE_DEFAULT in ('0' , '-1') 
				set @length='max'
			set @sql_segment = @sql_segment COLLATE DATABASE_DEFAULT +' ('+@length COLLATE DATABASE_DEFAULT  + ')'
		end
			
		set @sql_segment = @sql_segment	COLLATE DATABASE_DEFAULT +  ' COLLATE DATABASE_DEFAULT '
	end
	
	set @sql_segment = @sql_segment	COLLATE DATABASE_DEFAULT + @null_text COLLATE DATABASE_DEFAULT 
	
	insert into #sql values (@sql_segment)
		
	fetch next from @c into @id,@user_name,@table_name, @column_name, @length, @type_user_name, @type_name, @null_text, @is_user_type
end

close @c
deallocate @c
