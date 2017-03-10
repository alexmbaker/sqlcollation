--script drop of full text indexes
insert into #sql (sql)
select 'DROP FULLTEXT INDEX ON ['+s.name+'].['+o.name+']' as [sql] from sys.fulltext_indexes i join sys.objects o on i.object_id = o.object_id join sys.schemas s on o.schema_id = s.schema_id