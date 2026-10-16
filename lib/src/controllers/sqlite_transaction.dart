import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_dart_sql/maxi_dart_sql.dart';
import 'package:maxi_dart_sqlite/src/controllers/sqlite_executor.dart';

class SqliteTransaction with DisposableMixin, DelegateLifetime implements SqlTransaction {
  final SqliteExecutor _executor;

  @override
  LifecycleScope get heart => _executor.heart;

  new({required this._executor});

  @override
  SqlExecutor get executor => _executor;

  @override
  FutureResult<void> commit() => futureScopeVoid(() async {
    checkDisposed().$;
    (await _executor.executeRawSql('COMMIT TRANSACTION')).$;
    dispose();
  });

  @override
  FutureResult<void> rollback() => futureScopeVoid(() async {
    checkDisposed().$;
    (await _executor.executeRawSql('ROLLBACK TRANSACTION')).$;
    dispose();
  });
}
