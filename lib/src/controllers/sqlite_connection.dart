import 'dart:async';

import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_dart_sql/maxi_dart_sql.dart';
import 'package:maxi_dart_sqlite/maxi_dart_sqlite.dart';
import 'package:maxi_dart_sqlite/src/controllers/sqlite_executor.dart';
import 'package:maxi_dart_sqlite/src/controllers/sqlite_transaction.dart';

import 'package:sqlite3/sqlite3.dart';

class SqliteConnection with DisposableMixin, WithLifecycleScopeMixin implements SqlConnection {
  final SqliteConfiguration configuration;

  bool _isActive = false;
  bool _isConnected = false;

  Database? _instance;
  Timer? _timer;

  late final LockPoint _lockPoint;

  @override
  bool get isActive => _isActive;

  @override
  bool get isConnected => _isConnected;

  new({required this.configuration}) {
    _lockPoint = heart.attachChild(LockPoint());
  }

  @override
  FutureResult<SqlTransaction> buildTransaction<T>() => futureScopeValue(() async {
    checkDisposed().$;

    final lock = await $$_(_lockPoint.reserveKey(timeout: configuration.timeout));
    heart.attachHeart(lock.heart);
    SqliteExecutor? executor;

    try {
      final db = await $$_<Database>(_connect());
      executor = heart.attachChildWithHeart(SqliteExecutor(database: db, connection: this)).$;
      await $$_<void>(executor.executeRawSql('BEGIN TRANSACTION'));
      executor.heart.onDispose(lock.dispose);
      final newOperator = SqliteTransaction(executor: executor);
      return heart.attachChildWithHeart(newOperator).$;
    } finally {
      lock.dispose();
      executor?.dispose();
      _timer = heart.attachTimer(time: configuration.connectionKeepAliveTime, action: _onKeepAliveTimeout);
    }
  });

  @override
  FutureResult<T> reserve<T>(FutureResult<T> Function(SqlExecutor) action) => futureScopeValue(() async {
    checkDisposed().$;

    final lock = (await _lockPoint.reserveKey(timeout: configuration.timeout)).$;
    heart.attachHeart(lock.heart);
    SqliteExecutor? executor;

    try {
      final db = await $$_(_connect());
      executor = heart.attachChildWithHeart(SqliteExecutor(database: db, connection: this)).$;
      return (await action(executor)).$;
    } finally {
      lock.dispose();
      executor?.dispose();
      _timer = heart.attachTimer(time: configuration.connectionKeepAliveTime, action: _onKeepAliveTimeout);
    }
  });

  void _onKeepAliveTimeout() {
    _isConnected = false;
    _timer = null;

    _instance?.close();
    _instance = null;
  }

  void forceDisconnect() {
    if (_instance == null) return;

    _isConnected = false;
    _timer?.cancel();
    _timer = null;

    _instance?.close();
    _instance = null;
  }

  FutureResult<Database> _connect() => futureScopeValue(() async {
    checkDisposed().$;

    if (_isConnected && _instance != null) {
      _timer?.cancel();
      _timer = null;
      _isActive = true;
      return _instance!;
    }

    if (configuration.inMemory) {
      _instance = volatileScope(message: Oration('Failed to open SQLite database in memory'), function: () => sqlite3.openInMemory()).$;
    } else {
      final path = ResolveAddress(path: configuration.databasePath).run(heart).$;
      _instance = volatileScope(message: Oration('Failed to open SQLite database at path: $path'), function: () => sqlite3.open(path)).$;
    }

    _isActive = true;
    _isConnected = true;

    return _instance!;
  });

  @override
  void performDisposal() {
    super.performDisposal();
    _instance?.close();
    _instance = null;
    _isActive = false;
    _isConnected = false;
  }
}
