import "dart:async" show Future, Completer;
import "dart:collection" show Queue;
import "package:sql/driver.dart" show Driver;
import "package:sql/src/isolation_level.dart" show TransactionIsolationLevel;
import "package:sql/src/exceptions/pool_done_exception.dart"
    show PoolDoneException;
import "connection.dart";
import "result.dart" show Result, ResultSet;
import "statement.dart" show PreparedStatement;
import "transaction.dart" show Transaction;

/// Stats contains database statistics.
///
/// The statistics are representing the stats of database at the moment
/// of [Pool.stats].
class Stats {
  /// Total number of connections the pool may manage.
  final int capacity;

  /// Number of free connections.
  final int idle;

  /// Number of connections both those are currently free and in use.
  final int total;

  /// Number of connections that are currently in use.
  final int inUse;

  Stats._({this.capacity, this.idle, this.total, this.inUse});
}

/// Pool represents
abstract class Pool {
  /// Returns pool's underlying driver.
  Driver get driver;

  String get uri;

  /// Sets minimum number of free connections this pool should keep.
  ///
  /// If `num` is greater than `maxConns` it will be reduced to match
  /// the `maxConns` limit.
  ///
  /// If `num` is set to `0` no connections will be retained; if `num` is
  /// negative then corresponding [ArgumentError] will be thrown.
  set minIdleConns(int num);

  /// Sets maximum number of connections this pool may manage.
  ///
  /// Provided `num` must be positive integer, otherwise corresponding
  /// [ArgumentError] error will be thrown.
  ///
  /// If `0` is provided then capacity of the pool is considered infinite.
  set maxConns(int num);

  /// Sets maximum period for which newly open connection may be reused.
  ///
  /// Expiration time of connection is checked lazily at the time of receipt it
  /// from the pool and returning it back.
  ///
  /// If connection is expired it will be removed from the entire pool.
  set maxConnLifetime(Duration maxConnLifetime);

  /// Returns database statistics such as count of idling, in-use connections,
  /// pool capacity and etc.
  Stats get stats;

  /// A future that is completed when pool is closed and all underlying
  /// connections are released.
  Future<void> get done;

  /// Retrieves whether pool is closed.
  ///
  /// Pool is considered closed when [close] is invoked.
  bool get isClosed;

  /// Closes all underlying connections and then resets pool internals.
  ///
  /// Connections that are in use may cancel ongoing progress (e.g. rollback
  /// open transactions, etc.).
  Future<void> close();

  Future<bool> ping();

  Future<Transaction> begin(
      {TransactionIsolationLevel isolationLevel =
          TransactionIsolationLevel.initial,
      bool readOnly = false});

  Future<PreparedStatement> prepare(String sql, [List<Object> args]);

  Future<Result> execute(String sql, [List<Object> args]);

  Future<ResultSet> query(String sql, [List<Object> args]);
}

class PoolImpl extends Pool {
  final Driver _driver;
  final String _uri;
  final Completer<void> _completer = Completer();

  bool _isConnPingable = false;
  bool _isConnExecutable = false;
  bool _isConnQueryable = false;

  int _connID = 0;
  int _inUseConns = 0;
  int _closedMaxLifetimeConns = 0;
  int _closedMaxConns = 0;
  bool _isClosed = false;

  int _minIdleConns = 5;
  int _maxConns = 0;
  Duration _maxConnLifetime;

  final Queue<Completer<ConnectionImpl>> _idle = Queue(); // free conns
  final Queue<Completer<ConnectionImpl>> _wait = Queue();
  final Map<int, ConnectionImpl> _all = {}; // all conns

  PoolImpl(this._driver, this._uri)
      : _isConnPingable = _driver.capabilities.isConnPingable,
        _isConnExecutable = _driver.capabilities.isConnExecutable,
        _isConnQueryable = _driver.capabilities.isConnQueryable;

  int get _idleConns => _idle.length;

  int get _totalConns => _all.length;

  @override
  set maxConns(int maxConns) {
    assert(maxConns != null);

    if (maxConns.isNegative) {
      throw ArgumentError.value(maxConns, "maxConns");
    }

    _maxConns = maxConns;
  }

  @override
  set minIdleConns(int minIdleConns) {
    assert(minIdleConns != null);

    if (minIdleConns.isNegative) {
      throw ArgumentError.value(minIdleConns, "minIdleConns");
    }

    if (minIdleConns > _maxConns) {
      _minIdleConns = _maxConns;
    } else {
      _minIdleConns = minIdleConns;
    }
  }

  @override
  set maxConnLifetime(Duration maxConnLifetime) =>
      _maxConnLifetime = maxConnLifetime;

  @override
  Driver get driver => _driver;

  @override
  String get uri => _uri;

  @override
  Stats get stats => Stats._(
      idle: _idleConns,
      total: _totalConns,
      inUse: _inUseConns,
      capacity: _maxConns);

  @override
  Future<void> get done => _completer.future;

  @override
  bool get isClosed => _isClosed;

  Future<T> _once<T>(Future<T> callback(Connection conn)) async {
    if (isClosed) {
      throw PoolDoneException("Pool is closed!");
    }

    Connection conn;
    T result;

    try {
      conn = await connect();
      result = await callback(conn);
    } catch (err) {
      // code
    } finally {
      await conn.close();
    }

    return result;
  }

  Future<void> _close() => Future.wait(_all.values.map((conn) => conn.close()))
          .then<void>((_) => _cleanUp())
          .then<void>((_) {
        _isClosed = true;

        _completer.complete();

        return _completer.future;
      });

  void _cleanUp() {
    _all.clear();
    _idle.clear();
    _wait.clear();

    _connID = 0;
    _closedMaxConns = 0;
    _closedMaxLifetimeConns = 0;
  }

  /// Initializes a pool, creates n-th connections to database.
  Future<void> initialize() {
    final conns = <Future<Connection>>[];

    for (int i = 0; i < _minIdleConns; i++) {
      conns.add(connect());
    }

    return Future.wait(conns);
  }

  void release(ConnectionImpl conn) {
    if (conn.createdAt.difference(DateTime.now()) < _maxConnLifetime) {
      try {
        conn.conn.close();
      } catch (err) {}
    }
  }

  Future<Connection> connect() async {
    final conn = await _driver.connect(uri);

    return ConnectionImpl(this, conn,
        id: _connID++,
        isConnPingable: _isConnPingable,
        isConnExecutable: _isConnExecutable,
        isConnQueryable: _isConnQueryable);
  }

  @override
  Future<void> close() {
    if (isClosed) {
      return Future.error(PoolDoneException("Pool is closed!"));
    }

    return _close();
  }

  @override
  Future<bool> ping() => _once<bool>((conn) => conn.ping());

  @override
  Future<Transaction> begin(
          {TransactionIsolationLevel isolationLevel =
              TransactionIsolationLevel.initial,
          bool readOnly = false}) =>
      connect().then((conn) =>
          conn.begin(isolationLevel: isolationLevel, readOnly: readOnly));

  @override
  Future<PreparedStatement> prepare(String sql, [List<Object> args]) =>
      _once<PreparedStatement>((conn) => conn.prepare(sql));

  @override
  Future<Result> execute(String sql, [List<Object> args]) =>
      _once<Result>((conn) => conn.execute(sql, args));

  @override
  Future<ResultSet> query(String sql, [List<Object> args]) =>
      _once<ResultSet>((conn) => conn.query(sql, args));
}
