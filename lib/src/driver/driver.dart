import "dart:async" show FutureOr;
import "package:sql/sql.dart" as sql show Pool;
import "connection.dart" show Connection, Pinger, Querier;

/// [DriverOptions] represents particular driver's capability, i.e. flags
/// indicating that various optional `sql/driver.dart` interfaces
/// (e.g. [Pinger], [Querier] etc.) are implemented by this driver.
class DriverCapabilities {
  /// Indicates whether driver connection implements [Pinger] interface.
  final bool isConnPingable;

  /// Indicates whether driver connection implements [Querier] interface.
  ///
  /// If flag is not set, [sql] package will try to determine this capability
  /// based on runtime reflection.
  ///
  /// If flag is explicitly set to `false`, [sql.Pool] will prepare
  /// SQL statement query on it, close and then return the result.
  final bool isConnQueryable;

  /// Indicates whether driver connection implements [Executer] interface.
  ///
  /// If flag is not set, [sql] pacakge will try to determine this capability
  /// based on runtime reflection.
  ///
  /// If flag is explicitly set to `false`, [sql.Pool] will prepare
  /// SQL statement execute it, close and then return the result.
  final bool isConnExecutable;

  /// Indicates whether driver is capable to establish TCP connection
  /// using TLS.
  final bool isTlsCompatible;

  const DriverCapabilities(
      {this.isConnPingable,
      this.isTlsCompatible,
      this.isConnExecutable,
      this.isConnQueryable});
}

/// [Driver] represents a driver connector as well as config. manager
/// of particular driver package. It's mandatory to implement this interface.
///
/// Usually driver package should export single `driver` constant, so
/// it's easy to plug-in particular SQL driver.
abstract class Driver {
  /// Returns this driver implementation capabilities, helping to prevent
  /// some runtime checks to catch them on-the-fly.
  ///
  /// Along as this is optional whether to return particular [DriverCapabilities]
  /// or simply `null`, it's still highly recommended that driver returns
  /// correctly configured option set.
  ///
  /// If wrong options are marked as implemented it will lead to crash of
  /// the end-user app using this driver under certain circumstances.
  DriverCapabilities get capabilities;

  /// Returns a new driver connection connected to the database available
  /// at [uri].
  ///
  /// The driver is recommended to provide support for [uri] connection string
  /// in URI format and it  also may also support any other driver-specific
  /// format.
  ///
  /// Establishment of connection to the database may be performed
  /// both synchronously or asynchronously.
  ///
  /// It also can return a cached connection, but doing so is unnecessary as
  /// [sql] package maintains it's own connection pool.
  FutureOr<Connection> connect(String uri);
}
