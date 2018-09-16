import "dart:async" show Stream;

abstract class Row {}

abstract class Result {
  int get affectedRows;

  void close();
}

abstract class ResultSet implements Stream<Row> {}
