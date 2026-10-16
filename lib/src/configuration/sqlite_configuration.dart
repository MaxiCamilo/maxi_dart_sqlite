import 'package:maxi_dart_sql/maxi_dart_sql.dart';
import 'package:maxi_dart_sqlite/src/controllers/sqlite_connection.dart' if (dart.library.js_interop) 'package:maxi_dart_sqlite/src/fake_controllers/sqlite_connection.dart';

class SqliteConfiguration implements SqlConfiguration {
  final String databasePath;
  final bool inMemory;
  final Duration timeout;
  final Duration connectionKeepAliveTime;

  SqliteConfiguration._({required this.databasePath, required this.inMemory, this.timeout = const Duration(seconds: 30), this.connectionKeepAliveTime = const Duration(minutes: 5)});

  factory SqliteConfiguration.file({required String databasePath, Duration timeout = const Duration(seconds: 30), Duration connectionKeepAliveTime = const Duration(minutes: 5)}) {
    return SqliteConfiguration._(databasePath: databasePath, inMemory: false, timeout: timeout, connectionKeepAliveTime: connectionKeepAliveTime);
  }

  factory SqliteConfiguration.memory({Duration timeout = const Duration(seconds: 30), Duration connectionKeepAliveTime = const Duration(minutes: 5)}) {
    return SqliteConfiguration._(databasePath: ':memory:', inMemory: true, timeout: timeout, connectionKeepAliveTime: connectionKeepAliveTime);
  }

  @override
  SqlConnection buildConnection() {
    return SqliteConnection(configuration: this);
  }
}
