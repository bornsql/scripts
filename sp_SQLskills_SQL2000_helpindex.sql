/*============================================================================
  File:		sp_SQLskills_SQL2000_helpindex.sql

  Summary:	Based on sp_helpindex from SQL Server 2000, this script outputs
			an index structure in the same format as the 2005+ script by
			Kimberly Tripp
			
  See: https://www.sqlskills.com/blogs/kimberly/removing-duplicate-indexes/
  See also: http://bornsql.ca/s/script-duplicate-index-finder

  This script is called by sp_SQLskills_SQL2000_finddupes

  Date:		29 September 2017

  SQL Server Versions:
		SQL Server 2000
------------------------------------------------------------------------------
  Written by Randolph West, bornsql.ca
  Based on scripts developed by Kimberly L. Tripp, SQLSkills.com.

  Copyright (c) Born SQL.
 
  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE master
GO

IF OBJECTPROPERTY(OBJECT_ID('sp_SQLskills_SQL2000_helpindex'), 'IsProcedure') = 1
	DROP PROCEDURE sp_SQLskills_SQL2000_helpindex
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_SQLskills_SQL2000_helpindex] @objname NVARCHAR(776) -- the table to check for indexes
AS
--  September 2013: Moved to GitHub.
--  May 2013: Worked around RID / UNIQUIFIER not displaying correctly.
--  August 2012: Updated copyright bits, cleaned up formatting and
--               comments.

--   March 2012: Based on SQL Server 2000 sp_helpindex with revised
--               code for columns in index levels.

-- For the original script, updates and/or additional information, see
-- http://www.SQLskills.com/blogs/Kimberly (Kimberly L. Tripp)

-- For updates to this port of the script, see
-- http://BornSQL.ca (Randolph West)

-- PRELIM
SET NOCOUNT ON

DECLARE @objid INT, -- the object id of the table
	@indid SMALLINT, -- the index id of an index
	@groupid SMALLINT, -- the filegroup id of an index
	@indname SYSNAME,
	@groupname SYSNAME,
	@status INT,
	@keys NVARCHAR(2126), --Length (16*max_identifierLength)+(15*2)+(16*3)
	@dbname SYSNAME

-- Check to see that the object names are local to the current database.
SELECT @dbname = PARSENAME(@objname, 3)

IF @dbname IS NOT NULL
	AND @dbname <> DB_NAME()
BEGIN
	RAISERROR (15250, -1, -1)
	RETURN (1)
END

-- Check to see the the table exists and initialize @objid.
SELECT @objid = OBJECT_ID(@objname)

IF @objid IS NULL
BEGIN
	SELECT @dbname = DB_NAME()
	RAISERROR (15009, -1, -1, @objname, @dbname)
	RETURN (1)
END

-- OPEN CURSOR OVER INDEXES (skip stats: bug shiloh_51196)
DECLARE ms_crs_ind CURSOR LOCAL STATIC
FOR
SELECT [indid],
	[groupid],
	QUOTENAME(NAME, N']'),
	[status]
FROM sysindexes
WHERE [id] = @objid
	AND [indid] > 0
	AND [indid] < 255
	AND ([status] & 64) = 0
ORDER BY indid

OPEN ms_crs_ind

FETCH ms_crs_ind
INTO @indid,
	@groupid,
	@indname,
	@status

-- IF NO INDEX, QUIT
IF @@FETCH_STATUS < 0
BEGIN
	DEALLOCATE ms_crs_ind
	RAISERROR (15472, -1, -1) --'Object does not have any indexes.'
	RETURN (0)
END

-- create temp table
CREATE TABLE #spindtab (
	[index_id] INT,
	[index_name] SYSNAME COLLATE database_default NOT NULL,
	[stats] INT,
	[groupname] SYSNAME COLLATE database_default NOT NULL,
	[index_keys] NVARCHAR(2126) COLLATE database_default NOT NULL -- see @keys above for length descr
	)

-- Now check out each index, figure out its type and keys and
--	save the info in a temporary table that we'll print out at the end.
WHILE @@FETCH_STATUS >= 0
BEGIN
	-- First we'll figure out what the keys are.
	DECLARE @i INT,
		@thiskey NVARCHAR(131) -- 128+3

	SELECT @keys = QUOTENAME(INDEX_COL(@objname, @indid, 1), N']'),
		@i = 2

	IF (INDEXKEY_PROPERTY(@objid, @indid, 1, 'IsDescending') = 1)
		SELECT @keys = @keys + '(-)'

	SELECT @thiskey = INDEX_COL(@objname, @indid, @i)

	IF (
			(@thiskey IS NOT NULL)
			AND (INDEXKEY_PROPERTY(@objid, @indid, @i, 'IsDescending') = 1)
			)
		SELECT @thiskey = @thiskey + '(-)'

	WHILE (@thiskey IS NOT NULL)
	BEGIN
		SELECT @keys = @keys + ', ' + QUOTENAME(@thiskey, N']'),
			@i = @i + 1

		SELECT @thiskey = INDEX_COL(@objname, @indid, @i)

		IF (
				(@thiskey IS NOT NULL)
				AND (INDEXKEY_PROPERTY(@objid, @indid, @i, 'IsDescending') = 1)
				)
			SELECT @thiskey = @thiskey + '(-)'
	END

	SELECT @groupname = groupname
	FROM sysfilegroups
	WHERE groupid = @groupid

	-- INSERT ROW FOR INDEX
	INSERT INTO #spindtab
	VALUES (
		@indid,
		@indname,
		@status,
		@groupname,
		@keys
		)

	-- Next index
	FETCH ms_crs_ind
	INTO @indid,
		@groupid,
		@indname,
		@status
END

DEALLOCATE ms_crs_ind

-- SET UP SOME CONSTANT VALUES FOR OUTPUT QUERY
DECLARE @empty VARCHAR(1)

SELECT @empty = ''

DECLARE @des1 VARCHAR(35), -- 35 matches spt_values
	@des2 VARCHAR(35),
	@des4 VARCHAR(35),
	@des32 VARCHAR(35),
	@des64 VARCHAR(35),
	@des2048 VARCHAR(35),
	@des4096 VARCHAR(35),
	@des8388608 VARCHAR(35),
	@des16777216 VARCHAR(35)

SELECT @des1 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 1

SELECT @des2 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 2

SELECT @des4 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 4

SELECT @des32 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 32

SELECT @des64 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 64

SELECT @des2048 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 2048

SELECT @des4096 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 4096

SELECT @des8388608 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 8388608

SELECT @des16777216 = [name]
FROM master.dbo.spt_values
WHERE [type] = 'I'
	AND [number] = 16777216

-- Simple workaround to establish the tree-level columns included
DECLARE @clustered_index NVARCHAR(4000)
DECLARE @uniquifier BIT

SELECT @clustered_index = ISNULL(index_keys, 'RID'),
	@uniquifier = CASE 
		WHEN index_keys IS NOT NULL
			AND (stats & 2) = 0
			THEN 1
		ELSE 0
		END
FROM #spindtab
WHERE index_id = 1

-- DISPLAY THE RESULTS
--(stats & 1) <> 0 = ignore_duplicate_keys
--(stats & 2) <> 0 = unique
--(stats & 4) <> 0 = ignore_duplicate_rows
--(stats & 16) <> 0 = clustered
--(stats & 32) <> 0 = hypothetical
--(stats & 64) <> 0 statistics
--(stats & 2048) <> 0 = primary_key
--(stats & 4096) <> 0 = unique_key
--(stats & 8388608) <> 0 = auto_create
--(stats & 16777216) <> 0 = stats_no_recompute

SELECT index_id,
	index_name,
	CONVERT(VARCHAR(210), --bits 16 off, 1, 2, 16777216 on, located on group
		CASE 
			WHEN (stats & 16) <> 0
				THEN 'clustered'
			ELSE 'nonclustered'
			END + CASE 
			WHEN (stats & 1) <> 0
				THEN ', ' + @des1
			ELSE @empty
			END + CASE 
			WHEN (stats & 2) <> 0
				THEN ', ' + @des2
			ELSE @empty
			END + CASE 
			WHEN (stats & 4) <> 0
				THEN ', ' + @des4
			ELSE @empty
			END + CASE 
			WHEN (stats & 64) <> 0
				THEN ', ' + @des64
			ELSE CASE 
					WHEN (stats & 32) <> 0
						THEN ', ' + @des32
					ELSE @empty
					END
			END + CASE 
			WHEN (stats & 2048) <> 0
				THEN ', ' + @des2048
			ELSE @empty
			END + CASE 
			WHEN (stats & 4096) <> 0
				THEN ', ' + @des4096
			ELSE @empty
			END + CASE 
			WHEN (stats & 8388608) <> 0
				THEN ', ' + @des8388608
			ELSE @empty
			END + CASE 
			WHEN (stats & 16777216) <> 0
				THEN ', ' + @des16777216
			ELSE @empty
			END + ' located on ' + groupname) AS [index_description],
	index_keys,
	CASE 
		WHEN (stats & 2) = 0 /*non unique*/
			AND (stats & 16) = 0 /*non-clustered*/
			AND @uniquifier = 0
			THEN index_keys + ', ' + ISNULL(@clustered_index, 'RID')
		WHEN (stats & 2) = 0 /*non unique*/
			AND (stats & 16) = 0 /*non-clustered*/
			AND @uniquifier = 1
			THEN index_keys + ', ' + ISNULL(@clustered_index, 'RID') + ', UNIQUIFIER'
		WHEN (stats & 2) = 0 /*non unique*/
			AND (stats & 16) <> 0 /*clustered*/
			THEN index_keys + ', UNIQUIFIER'
		WHEN @clustered_index IS NOT NULL
			AND @uniquifier = 0
			THEN index_keys
		ELSE index_keys + ', RID'
		END AS [columns_in_tree],
	CASE 
		WHEN (stats & 2048) <> 0
			THEN 'All columns "included" - the leaf level IS the data row.'
		WHEN (stats & 4096) <> 0
			THEN index_keys + ', ' + @clustered_index
		WHEN (stats & 2) = 0 /*non unique*/
			AND (stats & 16) = 0 /*non-clustered*/
			AND @uniquifier = 0
			THEN index_keys + ', ' + ISNULL(@clustered_index, 'RID')
		WHEN (stats & 2) = 0 /*non unique*/
			AND (stats & 16) = 0 /*non-clustered*/
			AND @uniquifier = 1
			THEN index_keys + ', ' + ISNULL(@clustered_index, 'RID') + ', UNIQUIFIER'
		WHEN (stats & 2) = 0 /*non unique*/
			AND (stats & 16) <> 0 /*clustered*/
			THEN 'All columns "included" - the leaf level IS the data row.'
		WHEN (stats & 2) <> 0 /*unique*/
			AND (stats & 16) = 0 /*non-clustered*/
			THEN index_keys
		ELSE index_keys + ', RID'
		END AS [columns_in_leaf]
FROM #spindtab
ORDER BY index_id

DROP TABLE #spindtab

RETURN (0) -- sp_helpindex
GO

EXEC sp_MS_marksystemobject 'dbo.sp_SQLskills_SQL2000_helpindex'
GO
