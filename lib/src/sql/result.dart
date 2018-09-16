import "dart:async" show Stream,  StreamView;
import "package:sql/driver.dart" as driver show Result, ResultSet;

class Row {}

class RowImpl implements Row {}

abstract class Result {
  int get affectedRows;
}

class ResultImpl extends Result {
  final driver.Result _result;

  ResultImpl(this._result);

  int get affectedRows => _result.affectedRows;
}

abstract class ResultSet implements Stream<Row> {}

class ResultSetImpl extends StreamView<Row> implements ResultSet {
  final driver.ResultSet _resultSet;

  ResultSetImpl(this._resultSet) : super(_resultSet as Stream<Row>);
}
