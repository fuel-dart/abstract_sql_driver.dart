import "dart:async" show Future;
import "package:sql/driver.dart" as driver show PreparedStatement;
import "result.dart";

abstract class PreparedStatement {
  Future<void> close();

  Future<Result> execute([List<Object> args]);

  Future<ResultSet> query([List<Object> args]);
}

class PreparedStatementImpl implements PreparedStatement {
  final String _sql;
  final driver.PreparedStatement _stmt;

  PreparedStatementImpl(this._sql, this._stmt);

  @override
  Future<void> close() {}

  @override
  Future<Result> execute([List<Object> args]) {}

  @override
  Future<ResultSet> query([List<Object> args]) {}
}
