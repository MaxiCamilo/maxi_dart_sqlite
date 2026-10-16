@Timeout(Duration(minutes: 30))
library;

import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_dart_sql/maxi_dart_sql.dart';
import 'package:maxi_dart_sqlite/maxi_dart_sqlite.dart';
import 'package:test/test.dart';

void main() {
  final configuration = SqliteConfiguration.file(databasePath: 'test.db');

  group('Sqlite Tests', () {
    late final SqlConnection connection;

    setUp(() {
      connection = configuration.buildConnection();
    });

    test(
      'First DataBase Test',
      () => $$_(
        futureScopeVoid(() async {
          await $$_(
            connection.reserve((exe) async {
              await $$_(
                exe.executeTableCreation(
                  SqlCreateTableCommand(
                    tableName: 'Prueba',
                    columns: [
                      SqlColumnFormat(
                        name: 'id',
                        type: SqlColumnFormatType.intWithoutLimit,
                        isPrimaryKey: true,
                        isUniqueKey: false,
                        isAutoIncrement: true,
                      ),
                      SqlColumnFormat(
                        name: 'name',
                        type: SqlColumnFormatType.text,
                        isPrimaryKey: false,
                        isUniqueKey: true,
                        isAutoIncrement: false,
                      ),
                      SqlColumnFormat(
                        name: 'description',
                        type: SqlColumnFormatType.text,
                        isPrimaryKey: false,
                        isUniqueKey: false,
                        isAutoIncrement: false,
                      ),
                    ],
                    primaryKeysGroups: [],
                    uniqueKeysGroups: [],
                    foreignKeys: [],
                  ),
                ),
              );

              return Result.ok;
            }),
          );
        }),
      ),
    );
  });
}
