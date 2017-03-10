insert into #sql (sql) values ('set arithabort off')

-- finally set back to multi user access
if {4} = 1
begin
	insert into #sql values ('alter database [{0}] set multi_user')
end