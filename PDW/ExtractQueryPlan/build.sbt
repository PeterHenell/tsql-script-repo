lazy val root = (project in file(".")).
  settings(
    name := "ExtractQueryPlan",
    version := "1.0",
    scalaVersion := "2.12.8",
    mainClass in Compile := Some("jdbc.ScalaJdbcConnectSelect")
  )


