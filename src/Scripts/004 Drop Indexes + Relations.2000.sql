--work out which indexes will be dropped - we do this then work out which constrainst need to be dropped as 
--some constratins are dependant on primary keys

-- script drop of indexes - we will also populate a temp table that helps recreate the indexes later
create table #spindtab 
(
--	owner				sysname collate database_default NOT NULL,
	id					int NOT NULL,
	objectname			sysname collate database_default NOT NULL,
	index_name			sysname	collate database_default NOT NULL,
	stats				int,
	groupname			sysname collate database_default NULL,  --sometimes this is null - no idea why
	index_keys			nvarchar(3000)	collate database_default NOT NULL, -- see @ix_keys above for length descr
	OrigFillFactor			tinyint,
	IsAutoStatistic		bit
)

	--generate sql to do indexes

	declare 	@ix_indid smallint,	-- the index id of an index
			@ix_groupid smallint,  -- the filegroup id of an index
			@ix_indname sysname,
			@ix_groupname sysname,
			@ix_status int,
			@ix_keys nvarchar(3000),	
			@ix_dbname	sysname,
			@ix_ObjID int,
			@ix_ObjName sysname,
			@ix_OrigFillFactor tinyint,
			@ix_IsAutoStatistic bit

	-- Check to see the the table exists and initialize @ix_objid.

	-- OPEN CURSOR OVER INDEXES (skip stats: bug shiloh_51196)
	declare ms_crs_ind cursor local static for
		select i.id, '['+u.name+'].['+o.name+']' as objectname, i.indid, i.groupid, i.name, i.status, i.OrigFillFactor, case when (i.status & 64) = 0 then 0 else isnull(INDEXPROPERTY(i.id,i.name,'IsAutoStatistics'),0) end as IsAutoStatistic from sysindexes i
			join	sysobjects o
			on	i.id = o.id
			join	sysusers u
			on	u.uid = o.uid
			where /*id = @ix_objid and */i.indid > 0 and i.indid < 255 
			and  objectproperty(i.id,'ISMSSHIPPED')=0 and objectproperty(i.id,'IsTableFunction')=0 
			order by object_name(i.id),i.indid


	open ms_crs_ind
	fetch ms_crs_ind into @ix_objid, @ix_ObjName,@ix_indid, @ix_groupid, @ix_indname, @ix_status, @ix_OrigFillFactor, @ix_IsAutoStatistic


	-- Now check out each index, figure out its type and keys and
	--	save the info in a temporary table that we'll print out at the end.
	while @@fetch_status >= 0
	begin
		-- First we'll figure out what the keys are.
		declare @ix_i int, @ix_thiskey nvarchar(133) -- 128+5
		declare @rebuild_index bit
		declare @collation_id int
		
		select @ix_keys = '[' + index_col(@ix_objname, @ix_indid, 1)+']', @ix_i = 2, @rebuild_index={2} --parameter from application can force all to be rebuilt
		
		if (indexkey_property(@ix_objid, @ix_indid, 1, 'IsDescending') = 1)
			set @ix_keys = @ix_keys  + ' DESC'

		set @collation_id = (select collationid from syscolumns where id=@ix_objid and colid=indexkey_property(@ix_objid, @ix_indid, 1, 'columnid'))
		if @collation_id is not null and @collation_id<>0
			set @rebuild_index=1


		set @ix_thiskey = '[' + index_col(@ix_objname, @ix_indid, @ix_i) + ']'
		if ((@ix_thiskey is not null) and (indexkey_property(@ix_objid, @ix_indid, @ix_i, 'IsDescending') = 1))
			set @ix_thiskey = @ix_thiskey + ' DESC'

		set @collation_id = (select collationid from syscolumns where id=@ix_objid and colid=indexkey_property(@ix_objid, @ix_indid, @ix_i, 'columnid'))
		
		if @collation_id is not null and @collation_id<>0
			set @rebuild_index=1

		while (@ix_thiskey is not null )
		begin
			select @ix_keys = @ix_keys + ', ' + @ix_thiskey, @ix_i = @ix_i + 1

			set @collation_id = (select collationid from syscolumns where id=@ix_objid and colid=indexkey_property(@ix_objid, @ix_indid, @ix_i, 'columnid'))
			
			if @collation_id is not null and @collation_id<>0
				set @rebuild_index=1

			set @ix_thiskey = '[' + index_col(@ix_objname, @ix_indid, @ix_i) + ']'
			if ((@ix_thiskey is not null) and (indexkey_property(@ix_objid, @ix_indid, @ix_i, 'IsDescending') = 1))
				select @ix_thiskey = @ix_thiskey + ' DESC'
		end

		select @ix_groupname = groupname from sysfilegroups where groupid = @ix_groupid

		-- INSERT ROW FOR INDEX
		if @rebuild_index =1 
			insert into #spindtab values (@ix_objid, @ix_ObjName,@ix_indname, @ix_status, @ix_groupname, @ix_keys, @ix_OrigFillFactor, @ix_IsAutoStatistic)

		-- Next index
		fetch ms_crs_ind into @ix_objid, @ix_ObjName, @ix_indid, @ix_groupid, @ix_indname, @ix_status, @ix_OrigFillFactor, @ix_IsAutoStatistic
	end
	deallocate ms_crs_ind 

	


--drop constraints
insert into #sql (sql)
select 	'Alter table ['+ u.name + '].['+o.name+'] DROP CONSTRAINT [' + object_name(constid) + ']' 
from 	sysconstraints c
join	sysobjects o
on	c.id = o.id
join	sysusers u
on	u.uid = o.uid
where 	objectproperty(constid,'IsForeignKey')=1 
and 	constid in  (

	select 	fk.constid
	from 	sysforeignkeys fk
	join 	syscolumns fc
	on	fc.colid = fk.fkey
	and	fc.id = fk.fkeyid
	join 	syscolumns rc
	on	rc.colid = fk.rkey
	and	rc.id = fk.rkeyid
	where	(fc.collationid is not null and fc.collationid <> 0)
	or 	(rc.collationid is not null and rc.collationid <> 0)
	or	1={2} 
	
	union 
	
	select 	constid 
	from 	sysreferences  r
	join	#spindtab  i
	on	r.fkeyid = i.id
	
	)  --parameter allows all constraints to be dropped


--actually add the statments to drop the indexes


insert into #sql
select case when (stats & 4096)<>0 or (stats & 2048) <> 0 then
	--Constraint		
	'ALTER TABLE '+objectname+' DROP CONSTRAINT ['+index_name+'] ' 

	when (stats & 64) <> 0 then
	
	'DROP STATISTICS '+objectname+'.['+index_name+'] ' 
	
	else
	-- index

	'DROP INDEX '+objectname+'.['+ index_name +'] '
	end
from 	#spindtab 
