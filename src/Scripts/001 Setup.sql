--set up a temporary table for writing the generated script in to.

USE [{0}]
CREATE TABLE #sql (id INT PRIMARY KEY IDENTITY(1,1),sql NTEXT)

--get the single user option from the UI
IF {4} = 1
BEGIN
	INSERT INTO #sql (sql) VALUES (
		'IF EXISTS(SELECT 1 FROM sys.sysprocesses WHERE dbid = DB_ID(''{0}'') AND spid <> @@SPID) ' +
		'RAISERROR(''There appear to be other users connected to database "{0}". Please disconnect them and then proceed with running the script.'', 16, 1) WITH NOWAIT;'
	);

	INSERT INTO #sql (SQL) VALUES ('ALTER DATABASE [{0}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE  /* IF STUCK HERE FOR A LONG TIME, CHECK FOR OTHER USERS CONNECTED TO THE DATABASE! */')
END
INSERT INTO #sql (SQL) VALUES ('USE [{0}]')

INSERT INTO #sql (SQL) VALUES ('SET ARITHABORT ON')
