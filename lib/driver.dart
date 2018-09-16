library sql.driver;

/// Library introduces common interfaces to be implemented by database drivers
/// and are used by `sql` package.
///
/// To use this library in your code, try:
/// ```dart
/// import "package:sql/driver.dart";
/// ```

export "src/driver/connection.dart";
export "src/driver/driver.dart";
export "src/driver/result.dart";
export "src/driver/statement.dart";
export "src/driver/transaction.dart";
export "src/isolation_level.dart" show TransactionIsolationLevel;
