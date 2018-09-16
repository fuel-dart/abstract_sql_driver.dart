import "dart:async" show Future;
import "package:sql/src/isolation_level.dart";

abstract class Savepoint {
  String get name;
  int get id;
}

abstract class Transaction {
  bool get readOnly;
  TransactionIsolationLevel get isolationLevel;

  Future<void> get done;

  Future<void> commit();
  Future<void> rollback([Savepoint savepoint]);
  Future<Savepoint> savepoint([String name]);
}
