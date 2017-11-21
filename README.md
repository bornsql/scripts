# scripts
Miscellaneous Free Stuff

## Max Server Memory

For all versions from SQL Server 2005 up to and including SQL Server 2014, this script checks what your Max Server Memory setting should be, assuming that the server is a dedicated instance, and even prepares the `sp_configure` setting for you.

SQL Server 2016 and higher allows for additional physical RAM to be allocated for ColumnStore and In-Memory objects, so the script is not much use to you if you make use of these features. However, you're more than welcome to continue using it on these versions.

Supports Enterprise Edition and Standard Edition, and is version aware for the artificial RAM limits in Standard Edition.

## Power Saving Check

A simple Windows Registry scan, using `xp_cmdshell 'powercfg /list'`. This script respects your `'show advanced options'` and `'xp_cmdshell'` settings under `sp_configure`, and will set them back the way it found them.

## SQL Server 2000 Duplicate Index Finder

A backport of Kimberly L. Tripp's duplicate index finder for SQL Server 2005 and higher.
