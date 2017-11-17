exec sp_executesql N'
                create table #tmp_sp_catalogs (is_catalog_support bit null,server_name nvarchar(128) null, product_name nvarchar(128) null,provider_name nvarchar(128) null,catalog_name nvarchar(128) null, description nvarchar(4000) null)
                declare @ServerName sysname
                declare @ProductName sysname
				        declare @ProviderName sysname
                declare crs cursor local fast_forward
                for ( SELECT
srv.name AS [Name],
srv.product AS [ProductName],
srv.provider AS [ProviderName]
FROM
sys.servers AS srv
WHERE
(srv.server_id != 0)and(srv.name=@_msparam_0) ) 
                open crs 
                fetch crs into @ServerName,@ProductName,@ProviderName
                while @@fetch_status >= 0 
                begin		                                       				                     
                create table #tmp_catalog_exist_test (id int null,description sysname null,flags varchar null)
				        DECLARE @IsCatalogSupport bit  
                if (UPPER(@ProviderName) like ''SQLNCLI%'' ) 
					      begin  
                   set @IsCatalogSupport = 1                
                end
                else
                begin
                    insert into #tmp_catalog_exist_test(id,description,flags) EXEC master.dbo.xp_prop_oledb_provider @ProviderName                    
                    select @IsCatalogSupport = count(*) from #tmp_catalog_exist_test  where id = 233  
                end 
          if (@IsCatalogSupport = 0)
					begin
					insert into #tmp_sp_catalogs (catalog_name,is_catalog_support) values (''default'',0)										
					end
					else
					begin
					BEGIN TRY
					insert into #tmp_sp_catalogs (catalog_name,description) EXEC master.dbo.sp_catalogs @server_name = @ServerName
					update #tmp_sp_catalogs set is_catalog_support = 1
	                END TRY
					BEGIN CATCH
					insert into #tmp_sp_catalogs (catalog_name,is_catalog_support) values (''default'',0)   
				    END CATCH
					end
					update #tmp_sp_catalogs set server_name = @ServerName
					update #tmp_sp_catalogs set product_name = @ProductName
					update #tmp_sp_catalogs set provider_name = @ProviderName
					fetch crs into @ServerName,@ProductName,@ProviderName
			    end
				close crs
				deallocate crs



				create table #tmp_sp_tables_ex (is_catalog_error bit null,server_name nvarchar(128) null,server_catalog_name nvarchar(128) null,TABLE_CAT sysname null, TABLE_SCHEM sysname null,TABLE_NAME sysname null,TABLE_TYPE varchar(32) null,REMARKS varchar(254) null) 				
				create table #tmp_sp_tables_ex_all (TABLE_CAT sysname null, TABLE_SCHEM sysname null,TABLE_NAME sysname null,TABLE_TYPE varchar(32) null,REMARKS varchar(254) null)
                declare @TableServerName sysname
				declare @TableCatalogName sysname
				declare @IsCatalogSupportExist bit
                declare TableServerCrs cursor local fast_forward
                for ( SELECT
tsc.server_name AS [ServerName],
tsc.catalog_name AS [Name],
tsc.is_catalog_support AS [IsCatalogSupport]
FROM
sys.servers AS srv
INNER JOIN #tmp_sp_catalogs AS tsc ON tsc.server_name=srv.name
WHERE
(tsc.catalog_name=@_msparam_1 and tsc.is_catalog_support=@_msparam_2)and((srv.server_id != 0)and(srv.name=@_msparam_3)) ) 
                open TableServerCrs 
                fetch TableServerCrs into @TableServerName,@TableCatalogName,@IsCatalogSupportExist
                while @@fetch_status >= 0 
                begin
				IF (@IsCatalogSupportExist=0)
				BEGIN
				insert into #tmp_sp_tables_ex_all (TABLE_CAT,TABLE_SCHEM,TABLE_NAME,TABLE_TYPE,REMARKS) EXEC master.dbo.sp_tables_ex
			    @table_server = @TableServerName
			    ,@table_name = NULL
			    ,@table_schema = NULL
			    ,@table_catalog = NULL
			    ,@table_type = NULL
				insert into #tmp_sp_tables_ex (TABLE_CAT,TABLE_SCHEM,TABLE_NAME,TABLE_TYPE,REMARKS) select TABLE_CAT,TABLE_SCHEM,TABLE_NAME,TABLE_TYPE,REMARKS from #tmp_sp_tables_ex_all where TABLE_TYPE in  (''SYSTEM TABLE'',''TABLE'')
				update #tmp_sp_tables_ex set server_catalog_name = NULL
				END
				ELSE
				BEGIN
				insert into #tmp_sp_tables_ex_all (TABLE_CAT,TABLE_SCHEM,TABLE_NAME,TABLE_TYPE,REMARKS) EXEC master.dbo.sp_tables_ex
			    @table_server = @TableServerName
			    ,@table_name = NULL
			    ,@table_schema = NULL
			    ,@table_catalog = @TableCatalogName
			    ,@table_type = NULL
				insert into #tmp_sp_tables_ex (TABLE_CAT,TABLE_SCHEM,TABLE_NAME,TABLE_TYPE,REMARKS) select TABLE_CAT,TABLE_SCHEM,TABLE_NAME,TABLE_TYPE,REMARKS from #tmp_sp_tables_ex_all where TABLE_TYPE in  (''SYSTEM TABLE'',''TABLE'')
				update #tmp_sp_tables_ex set server_catalog_name = @TableCatalogName
				END				
                update #tmp_sp_tables_ex set server_name = @TableServerName																
                fetch TableServerCrs into @TableServerName,@TableCatalogName,@IsCatalogSupportExist
                end
                close TableServerCrs
                deallocate TableServerCrs


SELECT
tste.TABLE_NAME AS [Name],
ISNULL(tste.TABLE_SCHEM,'''') AS [Schema],
''Server[@Name='' + quotename(CAST(
        serverproperty(N''Servername'')
       AS sysname),'''''''') + '']'' + ''/LinkedServer[@Name='' + quotename(srv.name,'''''''') + '']'' + ''/LinkedServerCatalog[@Name='' + quotename(tsc.catalog_name,'''''''') + '' and @IsCatalogSupport='' + quotename(tsc.is_catalog_support,'''''''') + '']'' + ''/LinkedServerTable[@Name='' + quotename(tste.TABLE_NAME,'''''''') + '' and @Schema='' + quotename(ISNULL(tste.TABLE_SCHEM,''''),'''''''') + '']'' AS [Urn],
case when ( tste.TABLE_SCHEM in ('''') or (tste.TABLE_SCHEM IS NULL) ) then tste.TABLE_NAME else ISNULL(tste.TABLE_SCHEM,'''')+''.''+tste.TABLE_NAME end AS [SchemaObjectName],
case when tste.TABLE_TYPE in (''SYSTEM TABLE'') then 1 else 0 end AS [IsSystemObject]
FROM
sys.servers AS srv
INNER JOIN #tmp_sp_catalogs AS tsc ON tsc.server_name=srv.name
INNER JOIN #tmp_sp_tables_ex AS tste ON tste.server_name=tsc.server_name
WHERE
(case when tste.TABLE_TYPE in (''SYSTEM TABLE'') then 1 else 0 end=@_msparam_4)and((tsc.catalog_name=@_msparam_5 and tsc.is_catalog_support=@_msparam_6)and((srv.server_id != 0)and(srv.name=@_msparam_7)))
ORDER BY
[SchemaObjectName] ASC

			drop table #tmp_sp_tables_ex
			drop table #tmp_sp_tables_ex_all
		


				drop table #tmp_sp_catalogs
				drop table #tmp_catalog_exist_test
			

',N'@_msparam_0 nvarchar(4000),@_msparam_1 nvarchar(4000),@_msparam_2 nvarchar(4000),@_msparam_3 nvarchar(4000),@_msparam_4 nvarchar(4000),@_msparam_5 nvarchar(4000),@_msparam_6 nvarchar(4000),@_msparam_7 nvarchar(4000)',@_msparam_0=N'NETSUITE',@_msparam_1=N'Spotify AB',@_msparam_2=N'1',@_msparam_3=N'NETSUITE',@_msparam_4=N'0',@_msparam_5=N'Spotify AB',@_msparam_6=N'1',@_msparam_7=N'NETSUITE'