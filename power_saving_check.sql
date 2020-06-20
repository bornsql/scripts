/*
	Power Saving Check
	https://bornsql.ca/
	Copyright (c) BornSQL.ca
	Written by Randolph West, released under the MIT License
	Last updated: 19 June 2020

	A simple Windows Registry scan, using xp_cmdshell 'powercfg /list'.
	This script respects your 'show advanced options' and 'xp_cmdshell'
	settings under sp_configure, and will set them back the way it found
	them.

*/

DECLARE @isCmdShellEnabled BIT;
DECLARE @isShowAdvanced BIT;

SELECT @isCmdShellEnabled = CAST(value AS BIT)
FROM sys.configurations
WHERE name = 'xp_cmdshell';

SELECT @isShowAdvanced = CAST(value AS BIT)
FROM sys.configurations
WHERE name = 'show advanced options';

IF (@isShowAdvanced = 0)
BEGIN
	EXEC sp_configure 'show advanced options', 1;
	RECONFIGURE;
END;

IF (@isCmdShellEnabled = 0)
BEGIN
	EXEC sp_configure 'xp_cmdshell', 1;
	RECONFIGURE;
END;

--Run xp_cmdshell to get power settings
EXEC xp_cmdshell 'powercfg /list';

--Turn off 'xp_cmdshell'
IF (@isCmdShellEnabled = 0)
BEGIN
	EXEC sp_configure 'xp_cmdshell', 0;
	RECONFIGURE;
END;

--Turn off 'show advanced options'
IF (@isShowAdvanced = 0)
BEGIN
	EXEC sp_configure 'show advanced options', 0;
	RECONFIGURE;
END;
