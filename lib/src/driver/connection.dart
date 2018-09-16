import "dart:async" show Future;
import "package:sql/sql.dart" as sql show Pool, BadConnException;
import "package:sql/src/isolation_level.dart" show TransactionIsolationLevel;
import "result.dart" show Result, ResultSet;
import "statement.dart" show PreparedStatement;
import "transaction.dart" show Transaction;

/// [Connection] represents a connection to database.
abstract class Connection {
  /// Retrieves whether connection is closed.
  ///
  /// Driver must guarantee that this returns `true` only when
  /// [Connection.close] is invoked or error occurs.
  bool get isClosed;

  /// Returns future that is complete when this connection is closed, or
  /// when an error occurs.
  Future<void> get done;

  /// Closes this connection with invalidation and abort of current prepared
  /// statements and ongoing transactions.
  ///
  /// [Future] returned by this method is identical to future returned
  /// by [done].
  Future<void> close();

  Future<Transaction> begin(
      {TransactionIsolationLevel isolationLevel, bool readOnly = false});

  /// Prepares and returns a new [PreparedStatement] bound to this connection.
  Future<PreparedStatement> prepare(String sql, [List<Object> args]);
}

/// [Pinger] is an optional interface for [Connection] allows it to provide
/// pinging capability.
///
/// If driver connection doesn't implement this interface, [sql.Pool.ping]
/// may call a simple SQL statement (i.e. `select 1;`) to mimic connection
/// ping.
///
/// If pinged connection throws [sql.BadConnException] it will be removed from
/// parent [sql.Pool].
abstract class Pinger {
  Future<bool> ping();
}

abstract class Executer {
  Future<Result> execute(String sql, [List<Object> args]);
}

abstract class Querier {
  Future<ResultSet> query(String sql, [List<Object> args]);
}
