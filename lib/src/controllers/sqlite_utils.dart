import 'dart:developer';
import 'dart:typed_data';

import 'package:maxi_dart_framework/maxi_dart_framework.dart';
import 'package:maxi_dart_sql/maxi_dart_sql.dart';

mixin SqliteUtils {
  static const List<Type> _primitiveTypes = [int, double, String, bool, List<int>, Uint8List];

  static Result<List<dynamic>> distillParameters(Iterable rawValues) {
    final resultList = [];

    for (final item in rawValues) {
      if (_primitiveTypes.contains(item.runtimeType)) {
        resultList.add(item);
      } else if (item is Enum) {
        resultList.add(item.index);
      } else if (item is DateTime) {
        resultList.add(item.toUtc().millisecondsSinceEpoch);
      } else {
        return Result.error('The value %1 is of type %2, which is not supported as a parameter', [item, item.runtimeType.toString()]);
      }
    }

    return Result.value(resultList);
  }

  static String convertColumnType(SqlColumnFormatType type) {
    return switch (type) {
      SqlColumnFormatType.text => 'TEXT',
      SqlColumnFormatType.boolean => 'NUMERIC',
      SqlColumnFormatType.intWithoutLimit => 'INTEGER',
      SqlColumnFormatType.int8 => 'INTEGER',
      SqlColumnFormatType.int16 => 'INTEGER',
      SqlColumnFormatType.int32 => 'INTEGER',
      SqlColumnFormatType.int64 => 'INTEGER',
      SqlColumnFormatType.uintWithoutLimit => 'INTEGER',
      SqlColumnFormatType.uint8 => 'INTEGER',
      SqlColumnFormatType.uint16 => 'INTEGER',
      SqlColumnFormatType.uint32 => 'INTEGER',
      SqlColumnFormatType.uint64 => 'INTEGER',
      SqlColumnFormatType.doubleWithoutLimit => 'REAL',
      SqlColumnFormatType.decimal => 'REAL',
      SqlColumnFormatType.dateTime => 'INTEGER',
      SqlColumnFormatType.binary => 'BLOB',
      SqlColumnFormatType.dynamicType => 'BLOB',
    };
  }

  static String _convertConditionCompareToText(ConditionCompareType type) {
    return switch (type) {
      ConditionCompareType.equal => '=',
      ConditionCompareType.notEqual => '<>',
      ConditionCompareType.greater => '>',
      ConditionCompareType.less => '<',
      ConditionCompareType.greaterEqual => '>=',
      ConditionCompareType.lessEqual => '<=',
    };
  }

  static Result<(String, List)> buildConditions({required List<ReferenceCondition> conditions}) => resultScopeValue(() {
    if (conditions.isEmpty) {
      return ('', []);
    }

    final parts = <String>[];
    final values = <dynamic>[];

    for (final cond in conditions) {
      late final String column;

      if (cond is ReferenceOtherTable) {
        column = '${cond.tableName}.${cond.columnName}';
      } else {
        column = cond.name;
      }

      parts.add(_parseCondition(false, column, cond.condition, values));
    }

    return (parts.join(' AND '), values);
  });

  static String _parseCondition(bool beforeAntagonic, String column, Conditionator condition, List values) {
    if (condition is CompareValues) {
      final text = '${beforeAntagonic ? 'NOT (' : ''}"$column" ${_convertConditionCompareToText(condition.compareType)} ?${beforeAntagonic ? ')' : ''}';
      values.add(condition.origin);
      return text;
    } else if (condition is IncludeValues) {
      if (condition.values.isEmpty) {
        return '1=1';
      }
      final text = '"$column" ${beforeAntagonic ? 'NOT IN' : 'IN'} (${List.filled(condition.values.length, '?').join(', ')})';
      values.addAll(condition.values);
      return text;
    } else if (condition is SimilarText) {
      final text = '"$column" ${beforeAntagonic ? 'NOT LIKE' : 'LIKE'} ?';
      values.add('%${condition.text}%');
      return text;
    } else if (condition is AntagonicComparation) {
      return _parseCondition(!beforeAntagonic, column, condition.comparation, values);
    } else if (condition is MultiComparation) {
      final parts = condition.comparations.map((c) => _parseCondition(false, column, c, values)).toList();
      return '${beforeAntagonic ? 'NOT ' : ''}(${parts.join(condition.isConjunction ? ' AND ' : ' OR ')})';
    }
    throw ArgumentError('Unsupported condition type: ${condition.runtimeType}');
  }

  static String convertSelectFields(List<ColumnSelection> columns) {
    if (columns.isEmpty) {
      return '*';
    }

    final textsCommands = <String>[];
    for (final field in columns) {
      late String text;
      if (field.columnName == '') {
        text = '*';
      } else if (field.tableName != '') {
        text = '"${field.tableName}"."${field.columnName}"';
      } else {
        text = '"${field.columnName}"';
      }

      switch (field.function) {
        case ColumnSelectionFunction.field:
          break;
        case ColumnSelectionFunction.count:
          text = 'COUNT($text)';
          break;
        case ColumnSelectionFunction.maximum:
          text = 'MAX($text)';
          break;
        case ColumnSelectionFunction.minimum:
          text = 'MIN($text)';
          break;
        case ColumnSelectionFunction.sum:
          text = 'SUM($text)';
          break;
        case ColumnSelectionFunction.average:
          text = 'AVG($text)';
          break;
      }

      if (field.alias != '') {
        text = '$text AS "${field.alias}"';
      }

      textsCommands.add(text);
    }

    return textsCommands.join(', ');
  }

  static Result<String> convertSelectTable(List<TableSelection> tables) {
    if (tables.isEmpty) {
      return Result.error('No tables selected');
    }

    final textsCommands = tables
        .map((t) {
          if (t.tableName == '') {
            return '';
          } else if (t.alias != '') {
            return '"${t.tableName}" AS "${t.alias}"';
          } else {
            return '"${t.tableName}"';
          }
        })
        .where((text) => text.isNotEmpty)
        .toList();

    if (textsCommands.isEmpty) {
      return Result.error('No valid tables selected');
    }

    return Result.value(textsCommands.join(', '));
  }

  static String convertSelectJoiners(List<QueryJoiner> joiners) {
    if(joiners.isEmpty){
      return '';
    }

    final joinerBuffers = <String>[];
    final buffer = StringBuffer();

    for (final command in joiners) {
      if(command.conditions.isEmpty){
        log('Skipping joiner with no conditions: ${command.externalTable.tableName}');
        continue;
      }
      
      buffer.write(switch (command.type) {
        QueryJoinerFunction.inner => 'INNER JOIN ',
        QueryJoinerFunction.left => 'LEFT JOIN ',
        QueryJoinerFunction.right => 'RIGHT JOIN ',
        QueryJoinerFunction.fullOuter => 'FULL OUTER JOIN ',
      });

      late final String table;

      if (command.externalTable.alias.isEmpty) {
        table = command.externalTable.tableName;
        buffer.write('"${command.externalTable.tableName}"');
      } else {
        table = command.externalTable.alias;
        buffer.write('"${command.externalTable.tableName}" AS "${command.externalTable.alias}"');
      }

      buffer.write(' ON ');

      final conditions = <String>[];

      for (final condition in command.conditions) {
        final originColumn = command.originTable.alias.isEmpty ? command.originTable.tableName : command.originTable.alias;
        final externalColumn = table;
        final compareOperator = switch (condition.compareType) {
          ConditionCompareType.equal => '=',
          ConditionCompareType.notEqual => '!=',
          ConditionCompareType.greater => '>',
          ConditionCompareType.less => '<',
          ConditionCompareType.greaterEqual => '>=',
          ConditionCompareType.lessEqual => '<=',
        };

        conditions.add('"$originColumn"."${condition.originColumn}" $compareOperator "$externalColumn"."${condition.externalColumn}"');
      }

      buffer.write(conditions.join(' AND '));

      joinerBuffers.add(buffer.toString());
      buffer.clear();
    }

    return joinerBuffers.join('\n');
  }
}
