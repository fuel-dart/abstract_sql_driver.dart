import "package:sql/driver.dart" show Connection;

/// [TransactionIsolationLevel] represents a transaction isolation level
/// to be passed to [Connection.begin].
///
/// There are several predefined levels of isolation available:
/// [initial], [readUncommitted], [readCommitted], [writeCommitted],
/// [repeatableRead], [snapshot], [serializable], [linearizable] correspond to
/// "default", "read uncommitted", "read committed", "write committed",
/// "repeatable read", "snapshot", "serializable", "linearizable".
///
/// It isn't necessary drivers to support all of the predefined levels.
///
/// If driver supports other connections that are not provided by this library
/// it is allowed to define by driver itself.
///
///
/// See https://en.wikipedia.org/wiki/Isolation_(database_systems)#Isolation_levels
class TransactionIsolationLevel {
  final int value;
  final String _name;

  const TransactionIsolationLevel(this.value, [String name]) : _name = name;

  @override
  bool operator ==(dynamic other) =>
      other is TransactionIsolationLevel && value == other.value;

  @override
  String toString() {
    if (_name == null) {
      return "TransactionIsolationLevel($value)";
    }

    return _name;
  }

  static const TransactionIsolationLevel initial =
      TransactionIsolationLevel(0x0, "Default");
  static const TransactionIsolationLevel readUncommitted =
      TransactionIsolationLevel(0x1, "Read Uncommitted");
  static const TransactionIsolationLevel readCommitted =
      TransactionIsolationLevel(0x2, "Read Committed");
  static const TransactionIsolationLevel writeCommitted =
      TransactionIsolationLevel(0x3, "Write Committed");
  static const TransactionIsolationLevel repeatableRead =
      TransactionIsolationLevel(0x4, "Repeatable Read");
  static const TransactionIsolationLevel snapshot =
      TransactionIsolationLevel(0x5, "Snapshot");
  static const TransactionIsolationLevel serializable =
      TransactionIsolationLevel(0x6, "Serializable");
  static const TransactionIsolationLevel linearizable =
      TransactionIsolationLevel(0x7, "Linearizable");
}
