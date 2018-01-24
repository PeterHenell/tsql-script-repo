<#
.SYNOPSIS
  Runs a select with on the specified table with the specified columns 
  and writes the result to a CSV file.
  
.DESCRIPTION
  This function calls the connection passed as a parameter and sends a
  SELECT command to it. The table on which the SELECT is run as well as
  the selected columns are passed as a parameter.
  
  The results of the select are then saved in a CSV file, at the folder
  defined by the TargetFolder parameter with the name corresponding to the
  exported table name.

.ORIGINAL AUTHOR
  https://gist.github.com/Gimly/987708bdec70820d78f428981266e37e
  Extended by Peter henell
#>
function Export-TableToCsv (
  # An opened connection to a SQL database
  [Parameter(Mandatory = $true)]
  [String] $ConnectionString,
  
  # The folder where the file should be copied
  [Parameter(Mandatory = $true)]
  [ValidateScript({Test-Path $_ -PathType Container})]
  [String] $TargetFolder,
  
  # The name of the database table to export
  [Parameter(Mandatory = $true)]
  [String] $TableName,
  
  # The list of columns, defined by their names, to export
  [Parameter(Mandatory = $true)]  
  [String[]] $ColumnsToExport)
{    
  $ofs = ','
  $query = "SELECT $ColumnsToExport FROM $TableName"
  
  $connection =  New-Object System.Data.SqlClient.SqlConnection
  try 
  {
    $connection.ConnectionString = $connectionString
    
    $command = New-Object System.Data.SqlClient.SqlCommand
    $command.CommandText = $query
    $command.Connection = $Connection
    
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $command
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet)
    
    $DataSet.Tables[0] | Export-Csv "$TargetFolder/$TableName.csv" -NoTypeInformation -Encoding UTF8
  }
  finally
  {
    $connection.Dispose()
  }
}

function get_connection()
{
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder["Data Source"] = "dw-testb.spotify.net"
    $builder["Initial Catalog"] = "DWH_1_Raw"
    $builder["Integrated Security"] = $true
    $builder.ConnectionString
}
$con = get_connection

(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_JeType" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Transactions" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_CurrencyRates" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_CurrencyTemp" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_ConsolidatedExchangeRates" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_ReportDefinitionDetailTotal" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Counterpart" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_ReportDefinition" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Campaign" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_TransactionLinks" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_TransactionLines" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_ReportDefinitionDetailLeaf" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_GLAccount" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_TransactionIds" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Currency" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_LegalEntity" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_CostCenter" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Vendor" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Customer" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Project" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_PaymentMethod" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Partner" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Product" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_Market" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_AccountingPeriods" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_TransactionLineIds" "*")
(Export-TableToCsv "$con" "C:\temp\Output" "NetSuite_RawTyped.r_JournalClassification" "*")