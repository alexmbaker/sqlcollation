
	insert into #sql(sql)
	select 'EXEC sp_refreshview ''' + name + ''';'
	from sys.views
	order by name


