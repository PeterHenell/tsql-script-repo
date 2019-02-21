

package jdbc

import java.io.FileWriter
import java.sql.DriverManager
import java.sql.Connection
import java.util.Date
object ScalaJdbcConnectSelect {

  def outputToFile(output: String) = {
    var d = new Date().getTime()
    println(s"output to $d.sqlplan")
    val fw = new FileWriter(s"$d.sqlplan", true)
    try {
      fw.write( output)
    }
    finally fw.close()
  }

  def getExecutionPlan(connection: Connection, dist: String, spid : String) = {
    val statement = connection.createStatement()
    println(s"$dist / $spid")
    val resultSet = statement.executeQuery(s"DBCC PDW_SHOWEXECUTIONPLAN($dist,$spid)")
    while ( resultSet.next() ) {
      val host = resultSet.getString(1)
      outputToFile(host)
      println(host)
    }
  }


  def getCurrentSpid(connection: Connection): String = {
    var request_id = getSingleValueFromQuery(connection, s"select top 1 request_id from metadata.CurrentRunningQueries where login_name like 'JMETER%'")
//    val statement = connection.createStatement()
//    val resultSet = statement.executeQuery(s"select spid FROM sys.dm_pdw_sql_requests where request_id = '$request_id' and distribution_id = 1")
//    while ( resultSet.next() ) {
//      val request_id = resultSet.getString(1)
//    }
    val spid = getSingleValueFromQuery(connection, s"select spid FROM sys.dm_pdw_sql_requests where request_id = '$request_id' and distribution_id = 1")
    return spid
  }

  private def getSingleValueFromQuery(connection: Connection, query: String): String = {
    val statement = connection.createStatement()
    val resultSet = statement.executeQuery(query)
    while (resultSet.next()) {
      return resultSet.getString(1)
    }
    return "NO RESULT"
  }

  def main(args: Array[String]) {
    val driver = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
    val url = "jdbc:sqlserver://.database.windows.net:1433;database=;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30; "
    val username = ""
    val password = ""

    // there's probably a better way to do this
    var connection:Connection = null

//    println("Enter dist id")
//    var dist = scala.io.StdIn.readLine()
//    println("Enter spid")
//    var spid = scala.io.StdIn.readLine()

//    println(s"Dist: $dist, Spid: $spid")

    try {
      // make the connection
      Class.forName(driver)
      connection = DriverManager.getConnection(url, username, password)

      var spid = getCurrentSpid(connection)

      // create the statement, and run the select query
      getExecutionPlan(connection,"1", spid)

    } catch {
      case e => e.printStackTrace
    }
    connection.close()
  }

}