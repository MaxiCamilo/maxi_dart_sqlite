import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_dart_sql/maxi_dart_sql.dart';
import 'package:maxi_dart_sqlite/src/controllers/sqlite_connection.dart';
import 'package:maxi_dart_sqlite/src/controllers/sqlite_utils.dart';
import 'package:sqlite3/sqlite3.dart';

class SqliteExecutor with DisposableMixin, WithLifecycleScopeMixin implements SqlExecutor {
  final Database database;
  final SqliteConnection connection;

  SqliteExecutor({required this.database, required this.connection});

  FutureResult<void> executeRawSql(String sql, [List<Object?> parameters = const []]) => futureScopeVoid(() async {
    checkDisposed().$;
    volatileScope(message: Oration('Failed to execute SQL command'), function: () => database.execute(sql, parameters)).$;
  });

  FutureResult<TableResult> executeRawQuery(String sql, [List<Object?> parameters = const []]) => futureScopeValue(() async {
    checkDisposed().$;
    final resultSet = volatileScope(message: Oration('Failed to execute SQL command query'), function: () => database.select(sql, parameters)).$;
    final table = TableResult.withColumnsAndValues(columnsName: resultSet.columnNames, values: resultSet.toList());
    return table.$;
  });

  @override
  FutureResult<void> executeDelete(SqlDeleteCommand command) => futureScopeVoid(() async {
    checkDisposed().$;
    final buffer = StringBuffer();
    final shieldedValues = [];

    buffer.write('DELETE FROM "${command.tableName}"');

    if (command.conditions.isNotEmpty) {
      buffer.write('\n WHERE ');
      final (conditionText, conditionValues) = SqliteUtils.buildConditions(conditions: command.conditions).$;

      buffer.write(conditionText);
      shieldedValues.addAll(conditionValues);
    }

    buffer.write(';');

    (await executeRawSql(buffer.toString(), shieldedValues)).$;
  });

  @override
  FutureResult<void> executeInsert(SqlInsertCommand command) => futureScopeVoid(() async {
    checkDisposed().$;
    final buffer = StringBuffer();
    final shieldedValues = [];

    buffer.write('INSERT INTO "${command.tableName}" (');
    buffer.write(command.values.keys.join(', '));
    buffer.write(') VALUES (');
    buffer.write(List.filled(command.values.length, '?').join(', '));
    buffer.write(');');

    shieldedValues.addAll(command.values.values);

    (await executeRawSql(buffer.toString(), shieldedValues)).$;
  });

  @override
  FutureResult<void> executeUpdate(SqlUpdateCommand command) => futureScopeVoid(() async {
    checkDisposed().$;
    final buffer = StringBuffer();
    final shieldedValues = [];

    buffer.write('UPDATE "${command.tableName}" SET ');
    buffer.write(command.values.keys.map((key) => '$key = ?').join(', '));
    shieldedValues.addAll(command.values.values);

    if (command.conditions.isNotEmpty) {
      buffer.write('\n WHERE ');
      final (conditionText, conditionValues) = SqliteUtils.buildConditions(conditions: command.conditions).$;
      buffer.write(conditionText);
      shieldedValues.addAll(conditionValues);
    }

    buffer.write(';');

    (await executeRawSql(buffer.toString(), shieldedValues)).$;
  });

  @override
  FutureResult<void> executeTableCreation(SqlCreateTableCommand command) => futureScopeVoid(() async {
    checkDisposed().$;
    final buffer = StringBuffer();

    buffer.write('CREATE TABLE "${command.tableName}" (\n');
    buffer.write(
      command.columns
          .map((column) {
            final columnDef = StringBuffer();
            columnDef.write('"${column.name}" ${SqliteUtils.convertColumnType(column.type)}');
            if (column.isPrimaryKey) columnDef.write(' PRIMARY KEY');
            if (column.isAutoIncrement) columnDef.write(' AUTOINCREMENT');
            columnDef.write(' NOT NULL');
            return columnDef.toString();
          })
          .join(',\n'),
    );
    buffer.write('\n);');

    (await executeRawSql(buffer.toString(), [])).$;
  });

  @override
  FutureResult<TableResult> executeQuery(SqlQueryCommand command) => futureScopeValue(() async {
    final select = SqliteUtils.convertSelectFields(command.columns);
    final tables = SqliteUtils.convertSelectTable(command.tables).$;

    final joiners = SqliteUtils.convertSelectJoiners(command.joinedTables);
    final groupBy = command.grouped.map((x) => '"$x"').join(', ');
    final orderBy = command.orders.map((x) => '"${x.fields.join(', ')}" ${x.isAscendent ? 'ASC' : 'DESC'}').join(', ');

    final buffer = StringBuffer();
    final valueList = <dynamic>[];

    buffer.write('SELECT $select FROM $tables');
    if (joiners.isNotEmpty) {
      buffer.write('\n$joiners');
    }
    if (command.conditions.isNotEmpty) {
      final (conditionText, conditionValues) = SqliteUtils.buildConditions(conditions: command.conditions).$;
      buffer.write('\nWHERE $conditionText');
      valueList.addAll(conditionValues);
    }
    if (groupBy.isNotEmpty) {
      buffer.write('\nGROUP BY $groupBy');
    }
    if (orderBy.isNotEmpty) {
      buffer.write('\nORDER BY $orderBy');
    }

    if (command.havings.isNotEmpty) {
      final (havingText, havingValues) = SqliteUtils.buildConditions(conditions: command.havings).$;
      buffer.write('\nHAVING $havingText');
      valueList.addAll(havingValues);
    }

    buffer.write(';');

    return (await executeRawQuery(buffer.toString(), valueList)).$;
  });

  @override
  FutureResult<void> dropTable(String tableName) => futureScopeVoid(() async {
    final command = 'DROP TABLE IF EXISTS "$tableName";';
    await $$_(executeRawSql(command, []));
  });

  @override
  FutureResult<List<String>> getColumnNames(String tableName) => futureScope(() async {
    if (!await $$_(tableExists(tableName))) {
      return Result.error('Table ? does not exist', [tableName]);
    }

    final commandText = 'PRAGMA table_info($tableName);';
    final table = await $$_(executeRawQuery(commandText, []));
    if (table.isEmpty) {
      return Result.value([]);
    }

    return Result.value(table.getColumnByName(columnName: 'name').$.map((x) => x as String).toList());
  });

  @override
  FutureResult<bool> tableExists(String tableName) => futureScope(() async {
    final commandText = 'SELECT * FROM sqlite_master WHERE type=\'table\' AND name=?;';
    final result = await $$_(executeRawQuery(commandText, [tableName]));
    return Result.value(result.isNotEmpty);
  });
}
