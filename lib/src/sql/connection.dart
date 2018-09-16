import "dart:async" show Future;
import "package:meta/meta.dart" show required;
import "package:sql/driver.dart" as driver
    show Connection, Pinger, Executer, Querier;
import "package:sql/src/isolation_level.dart";
import "pool.dart" show PoolImpl;
import "result.dart";
import "statement.dart";
import "transaction.dart";

/// [Connection] represents a single database connection rather than
/// a pool of connections.
abstract class Connection {
  Future<void> close();

  Future<bool> ping();

  /// Begins a new transaction and returns it.
  ///
  /// Either [Transaction.commit] or [Transaction.rollback] must be called
  /// to free dedicated connection for transaction, or it may be timeouted with
  /// corresponding exception within a set time frame; otherwise if connection
  /// timeout is disabled and no mentioned methods are called, or no timeout
  /// functionality available, connection hangs forever.
  ///
  /// Optional [readOnly] may be set to mark transaction as read only; currently
  /// default to `false`; within [readOnly] transaction only reading operations
  /// are allowed, meaning that any writing operations will be declined with
  /// corresponding exception.
  ///
  /// It's also possible to set optional transaction [isolationLevel],
  /// some predefined levels are available, see [TransactionIsolationLevel]
  /// for more info; currently default to [TransactionIsolationLevel.initial].
  Future<Transaction> begin(
      {TransactionIsolationLevel isolationLevel =
          TransactionIsolationLevel.initial,
      bool readOnly = false});

  Future<PreparedStatement> prepare(String sql);

  Future<Result> execute(String sql, [List<Object> agrs]);

  Future<ResultSet> query(String sql, [List<Object> agrs]);
}

class ConnectionImpl extends Connection {
  final DateTime createdAt = DateTime.now();
  final int id;

  final bool _isConnPingable;
  final bool _isConnExecutable;
  final bool _isConnQueryable;

  final driver.Connection conn;
  final PoolImpl pool;

  ConnectionImpl(
    this.pool,
    this.conn, {
    @required this.id,
    @required bool isConnPingable,
    @required bool isConnQueryable,
    @required bool isConnExecutable,
  })  : _isConnPingable = isConnPingable,
        _isConnExecutable = isConnExecutable,
        _isConnQueryable = isConnQueryable;

  Future<void> _close() => Future.sync(() => pool.release(this));

  Future<bool> _ping() => query("SELECT 1;").then((result) {
        // code
      });

  Future<Result> _execute(String sql, [List<Object> args]) async {
    final stmt = await prepare(sql);

    final result = await stmt.execute(args);
    await stmt.close();

    return result;
  }

  Future<ResultSet> _query(String sql, [List<Object> args]) {}

  @override
  Future<void> close() => _close();

  @override
  Future<bool> ping() {
    if (_isConnPingable) {
      return (conn as driver.Pinger).ping();
    }

    return _ping();
  }

  @override
  Future<Transaction> begin(
          {TransactionIsolationLevel isolationLevel =
              TransactionIsolationLevel.initial,
          bool readOnly = false}) =>
      conn
          .begin(isolationLevel: isolationLevel, readOnly: readOnly)
          .then((transaction) => TransactionImpl(this, transaction));

  @override
  Future<PreparedStatement> prepare(String sql) {
    assert(sql != null);

    return conn.prepare(sql).then((stmt) => PreparedStatementImpl(sql, stmt));
  }

  @override
  Future<Result> execute(String sql, [List<Object> args]) {
    assert(sql != null);

    if (_isConnExecutable) {
      return (conn as driver.Executer)
          .execute(sql, args)
          .then((result) => ResultImpl(result));
    }

    return _execute(sql, args);
  }

  @override
  Future<ResultSet> query(String sql, [List<Object> args]) {
    assert(sql != null);

    if (_isConnQueryable) {
      return (conn as driver.Querier)
          .query(sql)
          .then((result) => ResultSetImpl(result));
    }

    return _query(sql, args);
  }
}
