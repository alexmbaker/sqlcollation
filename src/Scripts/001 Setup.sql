--set up a temporary table for switing the generated script in to.

USE [{0}]
create table #sql (id int primary key identity(1,1),sql nText)

--get the single user option from the UI
if {4} = 1
begin
	insert into #sql (sql) values ('alter database [{0}] set single_user')
end
insert into #sql (sql) values ('USE [{0}]')

insert into #sql (sql) values ('set arithabort on')
