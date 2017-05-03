--set up a temporary table for writing the generated script in to.

USE [{0}]
create table #sql (id int primary key identity(1,1),sql nText)

--get the single user option from the UI
if {4} = 1
begin
	insert into #sql (sql) values (
		'IF EXISTS(SELECT 1 FROM sys.sysprocesses WHERE dbid = DB_ID(''{0}'') AND spid <> @@SPID) ' +
		'RAISERROR(''There appear to be other users connected to database "{0}". Please disconnect them and then proceed with running the script.'', 16, 1) WITH NOWAIT;'
	);

	insert into #sql (sql) values ('alter database [{0}] set single_user   /* IF STUCK HERE FOR A LONG TIME, CHECK FOR OTHER USERS CONNECTED TO THE DATABASE! */')
end
insert into #sql (sql) values ('USE [{0}]')

insert into #sql (sql) values ('set arithabort on')
