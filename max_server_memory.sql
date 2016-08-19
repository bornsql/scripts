/*
    Max Server Memory Calculator
    https://bornsql.ca/memory/
    Copyright (c) 2016 BornSQL.ca
    Written by Randolph West, released under the MIT License
    Last updated: 19 August 2016

    Based on an original algorithm by Jonathan Kehayias:
    https://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/

    The algorithm requires the following reserved RAM for a server
    - 1 GB of RAM for the OS
    - plus 1 GB for each 4 GB of RAM installed from 4 – 16 GB
    - plus 1 GB for every 8 GB RAM installed above 16 GB RAM
    
    Thanks to @sqlEmt and @sqlstudent144 for testing
*/

DECLARE @physicalMemorySource DECIMAL(20, 4);
DECLARE @physicalMemory DECIMAL(20, 4);
DECLARE @recommendedMemory DECIMAL(20, 4);
DECLARE @overheadMemory DECIMAL(20, 4);

-- Get physical RAM on server
SELECT @physicalMemorySource = CAST(total_physical_memory_kb AS DECIMAL(20, 4)) / CAST((1024.0) AS DECIMAL(20, 4))
FROM sys.dm_os_sys_memory;

-- Convert to nearest GB
SELECT @physicalMemory = CEILING(@physicalMemorySource / CAST(1024.0 AS DECIMAL(20, 4)));

IF (@physicalMemory < 4.0)
BEGIN
	SELECT @overheadMemory = 2.0;
END;

IF @physicalMemory >= 4.0
	AND @physicalMemory <= 16.0
BEGIN
	SELECT @overheadMemory = 1.0 /* Operating System minimum */
		+ (@physicalMemory / 4.0);
END;

IF (@physicalMemory > 16.0)
BEGIN
	SELECT @overheadMemory = 1.0 /* Operating System minimum */ + 4.0 /* add in reserved for <= 16GB */
		+ ((@physicalMemory - 16.0) / 8.0);
END;

DECLARE @editionId BIGINT = CAST(SERVERPROPERTY('EditionID') AS BIGINT);
DECLARE @enterprise BIT = 0;
DECLARE @developer BIT = 0;
DECLARE @override BIT = 0;

IF (
		@editionId IN (
			1804890536,
			1872460670,
			610778273
			)
		)
BEGIN
	SELECT @enterprise = 1;
END;

IF (@editionId = - 2117995310)
	SELECT @developer = 1;

IF (
		@enterprise = 0
		AND @developer = 0
		)
BEGIN
	DECLARE @ProductVersion NVARCHAR(128) = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));

	IF (CAST(LEFT(@ProductVersion, 2) AS INT) >= 11)
		AND (@physicalMemory > 128)
	BEGIN
		SELECT @overheadMemory = 1.0 + 4.0 + ((128 - 16.0) / 8.0);

		-- Set the memory value to the max allowed, if there is enough headroom
		IF (@physicalMemory - @overheadMemory >= 128)
			SELECT @recommendedMemory = 128,
				@overheadMemory = 0,
				@override = 1;
	END;

	IF (CAST(LEFT(@ProductVersion, 2) AS INT) < 11)
		AND (@physicalMemory > 64)
	BEGIN
		SELECT @overheadMemory = 1.0 + 4.0 + ((64 - 16.0) / 8.0);

		-- Set the memory value to the max allowed, if there is enough headroom
		IF (@physicalMemory - @overheadMemory >= 64)
			SELECT @recommendedMemory = 64,
				@overheadMemory = 0,
				@override = 1;
	END;
END;

IF (@override = 0)
	SELECT @recommendedMemory = @physicalMemory - @overheadMemory;

SELECT @@VERSION AS [Version],
	CASE 
		WHEN (@enterprise = 1)
			THEN 'Enterprise Edition'
		WHEN (@developer = 1)
			THEN 'Developer Edition'
		ELSE 'Non-Enterprise Edition'
		END AS [Edition],
	CAST(@physicalMemorySource AS INT) AS [Physical RAM (MB)],
	--CAST(@physicalMemory AS INT) AS [Physical RAM (GB)],
	c.[value] AS [Configured Value (MB)],
	c.[value_in_use] AS [Running Value (MB)],
	CAST(@recommendedMemory * 1024 AS INT) AS [Recommended Value (MB)],
	N'EXEC sp_configure ''max server memory (MB)'', ' + CAST(CAST(@recommendedMemory * 1024 AS INT) AS NVARCHAR(20)) + '; RECONFIGURE WITH OVERRIDE;' AS [Script]
FROM sys.configurations c
WHERE [c].[name] = N'max server memory (MB)'
OPTION (RECOMPILE);
GO
