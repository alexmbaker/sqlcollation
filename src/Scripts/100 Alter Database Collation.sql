-- script the changing of the database collation
insert into #sql (sql) values ('USE [master]')
insert into #sql (sql) values ('alter database [{0}] collate {1}')
insert into #sql (sql) values ('USE [{0}]')