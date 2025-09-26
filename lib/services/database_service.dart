// Импорт платформо-зависимых функций
import 'dart:io' show Platform;
// Импорт утилит для работы с путями
import 'package:path/path.dart';
// Импорт основного пакета для работы с SQLite
import 'package:sqflite/sqflite.dart';
// Импорт основных классов Flutter
import 'package:flutter/foundation.dart';
// Импорт FFI реализации для desktop платформ
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) '';
// Импорт модели сообщения
import '../models/message.dart';

// Класс сервиса для работы с базой данных
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> _createMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        model_id TEXT,
        tokens INTEGER,
        cost REAL
      )
    ''');
  }

  Future<void> _createModelUsageStatsTable(Database db) async {
    await db.execute('''
      CREATE TABLE model_usage_stats (
        model_id TEXT PRIMARY KEY,
        total_tokens INTEGER NOT NULL DEFAULT 0,
        message_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chat_cache.db');

    return await openDatabase(
      path,
      version: 2, // <<< Увеличена версия БД
      onCreate: (Database db, int version) async {
        await _createMessagesTable(db);
        await _createModelUsageStatsTable(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // Если обновляемся с версии, где таблицы model_usage_stats не было
          await _createModelUsageStatsTable(db);
          // Опционально: можно попытаться заполнить model_usage_stats
          // данными из существующей таблицы messages, если это нужно.
          // Например, так:
          // await _populateModelUsageStatsFromMessages(db);
        }
      },
    );
  }

  // Опциональный метод для миграции данных, если нужно
  // Future<void> _populateModelUsageStatsFromMessages(Database db) async {
  //   try {
  //     final List<Map<String, dynamic>> messagesStats = await db.rawQuery('''
  //       SELECT 
  //         model_id,
  //         COUNT(*) as count,
  //         SUM(tokens) as tokens
  //       FROM messages 
  //       WHERE model_id IS NOT NULL AND tokens IS NOT NULL
  //       GROUP BY model_id
  //     ''');
  //     for (final stat in messagesStats) {
  //       final modelId = stat['model_id'] as String?;
  //       final count = stat['count'] as int? ?? 0;
  //       final tokens = stat['tokens'] as int? ?? 0;
  //       if (modelId != null) {
  //         await db.insert(
  //           'model_usage_stats',
  //           {'model_id': modelId, 'message_count': count, 'total_tokens': tokens},
  //           conflictAlgorithm: ConflictAlgorithm.replace,
  //         );
  //       }
  //     }
  //     debugPrint('Successfully populated model_usage_stats from messages table.');
  //   } catch (e) {
  //     debugPrint('Error populating model_usage_stats from messages: $e');
  //   }
  // }

  Future<void> saveMessage(ChatMessage message) async {
    try {
      final db = await database;
      await db.insert(
        'messages',
        {
          'content': message.content,
          'is_user': message.isUser ? 1 : 0,
          'timestamp': message.timestamp.toIso8601String(),
          'model_id': message.modelId,
          'tokens': message.tokens,
          'cost': message.cost,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<List<ChatMessage>> getMessages({int limit = 1000}) async { // Increased limit for fuller history consistency
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        orderBy: 'timestamp ASC',
        limit: limit, 
      );

      return List.generate(maps.length, (i) {
        return ChatMessage(
          content: maps[i]['content'] as String,
          isUser: maps[i]['is_user'] == 1,
          timestamp: DateTime.parse(maps[i]['timestamp'] as String),
          modelId: maps[i]['model_id'] as String?,
          tokens: maps[i]['tokens'] as int?,
          cost: maps[i]['cost'] as double?,
        );
      });
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      final db = await database;
      await db.delete('messages');
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  //--------- Методы для model_usage_stats ----------

  Future<void> updateModelUsage({required String model, required int tokensUsed}) async {
    try {
      final db = await database;
      // Используем транзакцию для атомарности
      await db.transaction((txn) async {
        final List<Map<String, dynamic>> existing = await txn.query(
          'model_usage_stats',
          where: 'model_id = ?',
          whereArgs: [model],
        );

        if (existing.isNotEmpty) {
          int currentTokens = existing.first['total_tokens'] as int? ?? 0;
          int currentCount = existing.first['message_count'] as int? ?? 0;
          await txn.update(
            'model_usage_stats',
            {
              'total_tokens': currentTokens + tokensUsed,
              'message_count': currentCount + 1,
            },
            where: 'model_id = ?',
            whereArgs: [model],
          );
        } else {
          await txn.insert(
            'model_usage_stats',
            {
              'model_id': model,
              'total_tokens': tokensUsed,
              'message_count': 1,
            },
          );
        }
      });
    } catch (e) {
      debugPrint('Error updating model usage for $model: $e');
    }
  }

  Future<Map<String, Map<String, int>>> getAllModelUsageStats() async {
    final stats = <String, Map<String, int>>{};
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query('model_usage_stats');

      for (final row in result) {
        final modelId = row['model_id'] as String;
        stats[modelId] = {
          'tokens': row['total_tokens'] as int? ?? 0,
          'count': row['message_count'] as int? ?? 0,
        };
      }
    } catch (e) {
      debugPrint('Error getting all model usage stats: $e');
    }
    return stats;
  }

  Future<void> clearModelUsageStats() async {
    try {
      final db = await database;
      await db.delete('model_usage_stats');
    } catch (e) {
      debugPrint('Error clearing model usage stats: $e');
    }
  }

  // Старый метод getStatistics, который агрегирует из таблицы messages.
  // Он может быть не нужен, если AnalyticsService теперь главный источник статистики.
  // Оставляю его пока для справки или если он где-то используется напрямую.
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final db = await database;
      final totalMessagesResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM messages');
      final totalMessages = Sqflite.firstIntValue(totalMessagesResult) ?? 0;

      final totalTokensResult = await db.rawQuery(
          'SELECT SUM(tokens) as total FROM messages WHERE tokens IS NOT NULL');
      final totalTokens = Sqflite.firstIntValue(totalTokensResult) ?? 0;

      final modelStats = await db.rawQuery('''
        SELECT 
          model_id,
          COUNT(*) as message_count,
          SUM(tokens) as total_tokens
        FROM messages 
        WHERE model_id IS NOT NULL 
        GROUP BY model_id
      ''');

      final modelUsage = <String, Map<String, int>>{};
      for (final stat in modelStats) {
        final modelId = stat['model_id'] as String;
        modelUsage[modelId] = {
          'count': stat['message_count'] as int,
          'tokens': stat['total_tokens'] as int? ?? 0,
        };
      }

      return {
        'total_messages': totalMessages,
        'total_tokens': totalTokens,
        'model_usage': modelUsage,
      };
    } catch (e) {
      debugPrint('Error getting statistics from messages table: $e');
      return {
        'total_messages': 0,
        'total_tokens': 0,
        'model_usage': {},
      };
    }
  }
}
