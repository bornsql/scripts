/*
	sp_SQL2000_finddupes.sql
	https://bornsql.ca/s/script-duplicate-index-finder/
	Copyright (c) BornSQL.ca
	Written by Randolph West, released under the MIT License
	Last updated: 19 June 2020

	Run against a single database, this procedure will list ALL
	duplicate indexes and the needed Transact-SQL to drop them!
	This is written specifically for SQL Server 2000.

	See: https://www.sqlskills.com/blogs/kimberly/removing-duplicate-indexes/

	-- June 2020: Renamed files, fixed formatting, and improved comments.

	-- September 2013: Moved to GitHub.

	-- May 2013: Worked around RID / UNIQUIFIER not displaying correctly.

	-- August 2012: Updated copyright bits, cleaned up formatting and
	--			    comments.

	--  March 2012: Based on SQL Server 2000 sp_helpindex with revised
	--			    code for columns in index levels.
*/

USE master
GO

IF OBJECTPROPERTY(OBJECT_ID('sp_SQL2000_finddupes'), 'IsProcedure') = 1
	DROP PROCEDURE sp_SQL2000_finddupes
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_SQL2000_finddupes]
(@ObjName NVARCHAR(776) = NULL -- the table to check for duplicates
-- when NULL it will check ALL tables
)
AS
SET NOCOUNT ON

DECLARE @ObjID INT, -- the object id of the table
		@DBName sysname,
		@SchemaName sysname,
		@TableName sysname,
		@ExecStr NVARCHAR(4000)

-- Check to see that the object names are local to the current database.
SELECT @DBName = PARSENAME(@ObjName, 3)

IF @DBName IS NULL
	SELECT @DBName = DB_NAME()
ELSE IF @DBName <> DB_NAME()
BEGIN
	RAISERROR(15250, -1, -1)
	-- select * from sys.messages where message_id = 15250
	RETURN (1)
END

IF @DBName IN ( N'tempdb' )
BEGIN
	RAISERROR('WARNING: This procedure cannot be run against tempdb. Skipping database.', 10, 0)
	RETURN (1)
END

-- Check to see the the table exists and initialize @ObjID.
SELECT @SchemaName = PARSENAME(@ObjName, 2)

IF @SchemaName IS NULL
	SELECT @SchemaName = 'dbo'

-- Check to see the the table exists and initialize @ObjID.
IF @ObjName IS NOT NULL
BEGIN
	SELECT @ObjID = OBJECT_ID(@ObjName)

	IF @ObjID IS NULL
	BEGIN
		RAISERROR(15009, -1, -1, @ObjName, @DBName)
		-- select * from sys.messages where message_id = 15009
		RETURN (1)
	END
END

CREATE TABLE #DropIndexes
(
	DatabaseName sysname,
	SchemaName sysname,
	TableName sysname,
	IndexName sysname,
	DropStatement NVARCHAR(2000)
)

-- Very hacky method to work around the VARCHAR(MAX) code in the
-- original script. This may need modification in the case of
-- very wide indexes and / or index names.

CREATE TABLE #FindDupes
(
	index_id INT,
	index_name sysname,
	index_description VARCHAR(210),
	index_keys NVARCHAR(1200),
	columns_in_tree NVARCHAR(1200),
	columns_in_leaf NVARCHAR(1200)
)

-- OPEN CURSOR OVER TABLE(S)
IF @ObjName IS NOT NULL
BEGIN
	DECLARE TableCursor CURSOR LOCAL STATIC FOR
	SELECT @SchemaName,
		   PARSENAME(@ObjName, 1)
END
ELSE
BEGIN
	DECLARE TableCursor CURSOR LOCAL STATIC FOR
	SELECT u.name,
		   t.name
	FROM sysobjects t
		INNER JOIN sysusers u
			ON t.uid = u.uid
	WHERE t.type = 'U' --AND name
	ORDER BY u.name,
			 t.name
END

OPEN TableCursor

FETCH TableCursor
INTO @SchemaName,
	 @TableName

-- For each table, list the add the duplicate indexes and save 
-- the info in a temporary table that we'll print out at the end.
WHILE @@FETCH_STATUS >= 0
BEGIN
	TRUNCATE TABLE #FindDupes

	SELECT @ExecStr
		= N'EXEC sp_SQL2000_helpindex ''' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N''''

	--SELECT @ExecStr
	INSERT #FindDupes
	EXEC (@ExecStr)

	--SELECT * FROM #FindDupes
	INSERT #DropIndexes
	SELECT DISTINCT
		   @DBName,
		   @SchemaName,
		   @TableName,
		   t1.index_name,
		   N'DROP INDEX ' + QUOTENAME(@SchemaName, N']') + N'.' + QUOTENAME(@TableName, N']') + N'.' + t1.index_name
	FROM #FindDupes AS t1
		JOIN #FindDupes AS t2
			ON t1.columns_in_tree = t2.columns_in_tree
			   AND t1.columns_in_leaf = t2.columns_in_leaf
			   AND PATINDEX('%unique%', t1.index_description) = PATINDEX('%unique%', t2.index_description)
			   AND t1.index_id > t2.index_id

	FETCH TableCursor
	INTO @SchemaName,
		 @TableName
END

DEALLOCATE TableCursor

-- DISPLAY THE RESULTS
/* RAISERROR replaced with a SELECT */
IF
(
	SELECT COUNT(*) FROM #DropIndexes
) = 0
	-- RAISERROR('Database: %s has NO duplicate indexes.', 10, 0, @DBName)
	SELECT 'Database ' + @DBName + ' has NO duplicate indexes.' AS [Results]
ELSE
	SELECT *
	FROM #DropIndexes
	ORDER BY SchemaName,
			 TableName

RETURN (0) -- sp_SQL2000_finddupes
GO

EXEC sp_MS_marksystemobject 'dbo.sp_SQL2000_finddupes'
GO
