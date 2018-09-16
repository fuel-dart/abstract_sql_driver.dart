import "dart:async" show Future;
import "package:sql/driver.dart" as driver show Driver, Connection;
import "package:sql/src/exceptions/driver_manager_exception.dart";
import "pool.dart" show Pool, PoolImpl;

class _DriverManager {
  final Map<String, driver.Driver> _drivers;

  // ignore: avoid_field_initializers_in_const_classes
  const _DriverManager() : _drivers = const {};

  void register(String name, driver.Driver driver) {
    assert(name != null);
    assert(driver != null);

    if (!_drivers.containsKey(name)) {
      throw DriverManagerException("");
    }

    _drivers[name] = driver;
  }

  void unregister(String name) {
    assert(name != null);

    if (!_drivers.containsKey(name)) {
      throw DriverManagerException("");
    }

    _drivers.remove(name);
  }

  Future<Pool> connect(String name, String uri) {
    assert(name != null);
    assert(uri != null);

    if (!_drivers.containsKey(name)) {
      return Future.error(DriverManagerException(""));
    }

    final driver = _drivers[name];
    final pool = PoolImpl(driver, uri);

    return pool.initialize().then((_) => pool);
  }
}

const _DriverManager _driverManager = _DriverManager();

/// Registers [driver] under specified [name].
///
/// If [driver] has been already registered corresponding exception
/// will be thrown.
void register(String name, driver.Driver driver) =>
    _driverManager.register(name, driver);

/// Unregister driver previously registered under [name].
///
/// If driver is not found corresponding exception will be thrown.
void unregister(String name) => _driverManager.unregister(name);

/// Creates a new pool of driver connections connected to specified [uri].
///
/// A driver must be registered under specified [name] before trying to
/// establish pool of connections, otherwise corresponding exception
/// will be thrown.
///
/// ```dart
/// import "package:sql/sql.dart" as sql;
/// import "package:mysql/mysql.dart" as mysql;
///
/// void main() async {
///   sql.register("mysql", mysql.driver);
///
///   try {
///     final pool = await sql.connect("mysql",
///         "mysql://root@127.0.0.1:33065/example");
///
///     // stuff...
///
///     final result = pool.query("select 1");
///
///     // other stuff...
///   } catch (exp) {
///     // handle exception...
///   }
/// }
/// ```
///
/// The returned pool maintains connections automatically. Therefore, [connect]
/// should be called only once.
Future<Pool> connect(String name, String uri) =>
    _driverManager.connect(name, uri);
