import "dart:async" show Completer, Future;
import "package:sql/driver.dart" as driver show Transaction, Savepoint;
import "package:sql/src/isolation_level.dart" show TransactionIsolationLevel;
import "connection.dart" show ConnectionImpl;
import "result.dart" show Result, ResultSet;
import "statement.dart" show PreparedStatement;

abstract class Savepoint {}

class SavepointImpl implements Savepoint {
  final Transaction transaction;
  final driver.Savepoint savepoint;

  SavepointImpl(this.transaction, this.savepoint);
}

abstract class Transaction {
  bool get readOnly;

  TransactionIsolationLevel get isolationLevel;

  /// Returns future that is complete when this transaction is finalized, means
  /// when either [rollback] or [commit] is called; or when an error occurs.
  Future<void> get done;

  Future<PreparedStatement> prepare(String sql);

  Future<Result> execute(String sql, [List<Object> args]);

  Future<ResultSet> query(String sql, [List<Object> args]);

  Future<void> commit();

  Future<void> rollback([Savepoint savepoint]);
}

class TransactionImpl implements Transaction {
  final Completer<void> _completer = Completer();
  ConnectionImpl _conn;
  driver.Transaction _transaction;

  TransactionImpl(this._conn, this._transaction);

  @override
  TransactionIsolationLevel get isolationLevel => _transaction.isolationLevel;

  @override
  bool get readOnly => _transaction.readOnly;

  @override
  Future<void> get done => _completer.future;

  /// Releases underlying connection to the pool. Resets this transaction,
  /// so it cannot be re-used later.
  ///
  /// It must only be called by either [rollback] or [commit].
  void _close() {
    _conn.close();

    _conn = null;
    _transaction = null;
  }

  @override
  Future<PreparedStatement> prepare(String sql) {
    return _conn.prepare(sql);
  }

  @override
  Future<Result> execute(String sql, [List<Object> args]) {}

  @override
  Future<ResultSet> query(String sql, [List<Object> args]) {}

  @override
  Future<void> rollback([Savepoint savepoint]) {
    if (savepoint != null) {
      return _transaction.rollback((savepoint as SavepointImpl).savepoint);
    }

    return _transaction.rollback().then((_) => _conn.close());
  }

  @override
  Future<void> commit() => _transaction.commit().then((_) => _close());

  @override
  Future<Savepoint> savepoint([String name]) => _transaction
      .savepoint(name)
      .then<Savepoint>((savepoint) => SavepointImpl(this, savepoint));
}
