import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_dart_sql/maxi_dart_sql.dart';
import 'package:maxi_dart_sqlite/maxi_dart_sqlite.dart';

class SqliteConnection implements SqlConnection {
  final SqliteConfiguration configuration;

  new({required this.configuration});

  @override
  bool get isActive => false;

  @override
  bool get isConnected => false;

  @override
  FutureResult<T> reserve<T>(FutureResult<T> Function(SqlExecutor) action) async {
    return Result.error('This platform does not support direct SQLite database administration');
  }

  @override
  FutureResult<SqlTransaction> buildTransaction<T>() async {
    return Result.error('This platform does not support direct SQLite database administration');
  }

  @override
  void dispose() {}
}
