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
    $builder["Data Source"] = "localhost"
    $builder["Initial Catalog"] = "master"
    $builder["Integrated Security"] = $true
    $builder.ConnectionString
}
$con = get_connection

(Export-TableToCsv "$con" "C:\temp\Output" "someTable" "*")