
declare @table_name sysname,
	@user_name sysname,
	@column_name sysname,
	@length nvarchar(100),
	@type_name sysname,
	@type_user_name sysname,
	@base_type_name sysname,
	@other_text nvarchar(4000),
	@null_text nvarchar(100),
	@id int,
	@c cursor,
	@sql_segment nvarchar(4000),
	@is_user_type bit

set 	@c = cursor for 

select 		o.id,
		u.name,
		o.name as table_name, 
		c.name as column_name, 
		case when t2.name like 'n%' then cast(c.length / 2 as nvarchar(100)) else cast(c.length as nvarchar(100)) end as Length, 
		u2.name as type_user_name,
		t.name as type_name,
		t2.name as base_type_name,
		case when c.isnullable=1 then 'NULL' else 'NOT NULL' end as nullable,
		case when t.xtype = t.xusertype then 0 else 1 end as is_user_type
from 		sysobjects o
join 		syscolumns c
on		o.id = c.id
join 		systypes t
on		t.xtype = c.xtype
and		t.xusertype = c.xusertype
--when this is a user data type we need to qualify the type user name
join 		sysusers u2
on		u2.uid = t.uid
--get the base type when column is a user type
join		systypes t2
on		t2.xtype = c.xtype
and		t2.xusertype = c.xtype

join		sysusers u
on		u.uid = o.uid
where 		o.type ='U'
and		objectproperty(o.id,'IsMSShipped')=0
and 		c.collationid is not null
and			c.collationid <> 0
--and 		c.collation <> cast(DATABASEPROPERTYEX(DB_NAME(),'collation') as sysname)

open @c

--actually we only need to go through this procedure for SQL 2000 as 2005 does allow 
--change of ntext columns...

fetch next from @c into @id,@user_name,@table_name, @column_name, @length, @type_user_name, @type_name,@base_type_name, @null_text, @is_user_type
while @@Fetch_Status = 0
begin
	if @base_type_name COLLATE DATABASE_DEFAULT in ('ntext','text')
	begin
		-- we can not use the alter table statment to change column level collation on text columns
		--we need to do each of these as a separate transaction dur to the risks of errors
		
		set @sql_segment = '
declare @InError bit
set 	@InError =0
begin transaction 
-- add a temp column
exec (''Alter table ['+@user_name+'].['+@table_name+'] add [____temp] [' + @base_type_name + ']'')

-- copy data to temp column
if @@error<>0 set @InError =1
if @@error = 0
	exec (''update ['+@user_name+'].['+@table_name+'] set [____temp] =[' + @column_name + ']'')



if @@error<>0 set @InError =1
if @@error = 0'
-- see if there is a default constraint on the column
-- if yes then must script drop / recreate
-- if not then we will need to create a temporary default constraint
-- when we add the column.

if exists (	select 	* 
		from 	sysconstraints  
		where 	id = @id
		and 	col_name(@id,colid) = @column_name
		and	(status & 5) = 5 )
begin
	-- yes there is a default constraint
	-- add code to drop the constraint
	
	set @sql_segment = @sql_segment + 

	(select '

	exec (''Alter table ['+@user_name+'].['+@table_name+'] drop constraint  [' + object_name(c.constid) + ']'')
if @@error<>0 set @InError =1
if @@error = 0

	exec (''Alter table ['+@user_name+'].['+@table_name+'] drop column [' + @column_name + ']'')
if @@error<>0 set @InError =1
if @@error = 0

	exec ('' ALTER TABLE ['+@user_name+'].['+@table_name+'] ADD ['+o.name+'] [' + @type_name + '] CONSTRAINT [' + object_name(c.constid) + '] DEFAULT ' + replace(t.text,'''','''''') + ' '+case when @is_user_type=1 then '' else @null_text end +' '')'
	from 	sysconstraints  c
	join 	syscolumns o
	on	c.id = o.id
	and	c.colid = o.colid
	join 	syscomments t
	on	t.id = c.constid
	where 	c.id = @id
	and 	(c.status & 5) = 5
	and 	col_name(c.id,c.colid) = @column_name) --default constraint
end	
else
begin
	set @sql_segment = @sql_segment + '
	-- drop origional column
	exec (''Alter table ['+@user_name+'].['+@table_name+'] drop column [' + @column_name + ']'')
	
if @@error<>0 set @InError =1
if @@error = 0'

	--no default constraint - if this is a NOT NULL column then we must create a temporary default 
	--constraint
	if @null_text='NOT NULL'
	begin

set @sql_segment = @sql_segment + '
	--add new column with correct collation and a temporary default constraint
	exec (''Alter table ['+@user_name+'].['+@table_name+'] add [' + @column_name+'] [' + @type_name + '] ' + case when @is_user_type=1 then '' else @null_text end +' CONSTRAINT [___CC_TEMP] DEFAULT ('''''''') '')

if @@error<>0 set @InError =1
if @@error = 0	
	--remove temporary default constraint
	exec (''alter table ['+@user_name+'].['+@table_name+'] drop constraint [___CC_TEMP]'')
'
	end
	else
	begin

		set @sql_segment = @sql_segment + '
	--add new column with correct collation
	exec (''Alter table ['+@user_name+'].['+@table_name+'] add [' + @column_name+'] [' + @type_name + '] ' + case when @is_user_type=1 then '' else @null_text end + ' '')'

	end


end

set @sql_segment =  @sql_segment  + '

if @@error<>0 set @InError =1
if @@error = 0
	-- Copy data back to origional column
	exec (''update ['+@user_name+'].['+@table_name+'] set [' + @column_name + '] = [____temp] '')


if @@error<>0 set @InError =1
if @@error = 0
	-- drop temp column
	exec (''alter table ['+@user_name+'].['+@table_name+'] drop column [____temp]'')
'

set @sql_segment =  @sql_segment  + '
if @@error<>0 set @InError =1
if @@error = 0
	commit transaction
else
	rollback transaction

'

	insert into #sql values (@sql_segment)
		

	end
	else
	begin
		-- normal columns
		set @sql_segment = 'Alter table ['+@user_name+'].['+@table_name COLLATE DATABASE_DEFAULT+'] Alter Column ['+@column_name COLLATE DATABASE_DEFAULT+ '] ['+@type_name COLLATE DATABASE_DEFAULT+']' 
	
		if @is_user_type=0
		begin
			if @type_name COLLATE DATABASE_DEFAULT in ('nvarchar', 'varchar','char','nchar')
			begin
				set @sql_segment = @sql_segment COLLATE DATABASE_DEFAULT +' ('+@length COLLATE DATABASE_DEFAULT  + ')'
			end
				
			set @sql_segment = @sql_segment	COLLATE DATABASE_DEFAULT +  ' COLLATE DATABASE_DEFAULT '
			
		end
		
		set @sql_segment = @sql_segment	COLLATE DATABASE_DEFAULT + @null_text COLLATE DATABASE_DEFAULT 
		
		insert into #sql values (@sql_segment)
		
	end	
	fetch next from @c into @id,@user_name,@table_name, @column_name, @length, @type_user_name, @type_name,@base_type_name, @null_text, @is_user_type
end

close @c
deallocate @c
