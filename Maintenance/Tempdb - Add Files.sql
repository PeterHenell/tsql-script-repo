USE [master]; 
GO 
alter database tempdb modify file (name='tempdev', size = 8GB, FILEGROWTH = 0);
GO
ALTER DATABASE [tempdb] ADD FILE (NAME = N'tempdev2', FILENAME = N'E:\MSSQL12.MSSQLSERVER\MSSQL\DATA\tempdev2.ndf' , SIZE = 8GB , FILEGROWTH = 0);
ALTER DATABASE [tempdb] ADD FILE (NAME = N'tempdev3', FILENAME = N'E:\MSSQL12.MSSQLSERVER\MSSQL\DATA\tempdev3.ndf' , SIZE = 8GB , FILEGROWTH = 0);
ALTER DATABASE [tempdb] ADD FILE (NAME = N'tempdev4', FILENAME = N'E:\MSSQL12.MSSQLSERVER\MSSQL\DATA\tempdev4.ndf' , SIZE = 8GB , FILEGROWTH = 0);
GO