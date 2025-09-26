// Импорт основных классов Flutter
import 'package:flutter/foundation.dart';
// Импортируем DatabaseService
import './database_service.dart'; // Предполагаем, что он в той же директории

// Сервис для сбора и анализа статистики использования чата
class AnalyticsService {
  // Единственный экземпляр класса (Singleton)
  static final AnalyticsService _instance = AnalyticsService._internal();
  // Экземпляр DatabaseService
  final DatabaseService _dbService = DatabaseService(); // Создаем экземпляр

  // Время начала сессии (остается для сессионной статистики)
  final DateTime _startTime;
  // Данные о сообщениях в текущей сессии (остаются сессионными)
  final List<Map<String, dynamic>> _sessionData = [];

  // _modelUsage больше не хранится в памяти напрямую, а получается из БД
  // final Map<String, Map<String, int>> _modelUsage = {}; // Удаляем или комментируем

  // Фабричный метод для получения экземпляра
  factory AnalyticsService() {
    return _instance;
  }

  // Приватный конструктор для реализации Singleton
  AnalyticsService._internal() : _startTime = DateTime.now();

  // Метод для отслеживания отправленного сообщения
  Future<void> trackMessage({ // Метод теперь асинхронный
    required String model, // Используемая модель
    required int messageLength, // Длина сообщения
    required double responseTime, // Время ответа
    required int tokensUsed, // Использовано токенов
  }) async {
    try {
      // Сохраняем/обновляем статистику в БД
      await _dbService.updateModelUsage(model: model, tokensUsed: tokensUsed);

      // Сохранение детальной информации о сообщении В ТЕКУЩЕЙ СЕССИИ
      _sessionData.add({
        'timestamp': DateTime.now().toIso8601String(),
        'model': model,
        'message_length': messageLength,
        'response_time': responseTime,
        'tokens_used': tokensUsed,
      });
    } catch (e) {
      debugPrint('Error tracking message: $e');
    }
  }

  // Метод получения общей статистики
  Future<Map<String, dynamic>> getStatistics() async { // Метод теперь асинхронный
    try {
      final now = DateTime.now();
      final sessionDuration = now.difference(_startTime).inSeconds;

      // Получаем статистику использования моделей из БД
      final modelUsageFromDb = await getModelUsageStatistics();

      // Подсчет общего количества сообщений и токенов
      int totalMessages = 0;
      int totalTokens = 0;

      for (final modelStats in modelUsageFromDb.values) {
        totalMessages += modelStats['count'] ?? 0;
        totalTokens += modelStats['tokens'] ?? 0;
      }

      final messagesPerMinute =
      sessionDuration > 0 ? (totalMessages * 60) / sessionDuration : 0.0;
      final tokensPerMessage =
      totalMessages > 0 ? totalTokens / totalMessages : 0.0;

      return {
        'total_messages': totalMessages,
        'total_tokens': totalTokens,
        'session_duration': sessionDuration,
        'messages_per_minute': messagesPerMinute,
        'tokens_per_message': tokensPerMessage,
        'model_usage': modelUsageFromDb, // Используем данные из БД
        'start_time': _startTime.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  // Метод экспорта данных текущей сессии (остается без изменений)
  List<Map<String, dynamic>> exportSessionData() {
    return List.from(_sessionData);
  }

  // Метод очистки всех данных
  Future<void> clearData() async { // Метод теперь асинхронный
    await _dbService.clearModelUsageStats(); // Очищаем статистику в БД
    _sessionData.clear(); // Очищаем сессионные данные
    debugPrint('Analytics data cleared (DB and session).');
  }

  // Метод анализа эффективности использования моделей
  Future<Map<String, double>> getModelEfficiency() async { // Метод теперь асинхронный
    final efficiency = <String, double>{};
    final modelUsageFromDb = await getModelUsageStatistics(); // Получаем из БД

    for (final entry in modelUsageFromDb.entries) {
      final modelId = entry.key;
      final stats = entry.value;
      final messageCount = stats['count'] ?? 0;
      final tokensUsed = stats['tokens'] ?? 0;

      if (messageCount > 0) {
        efficiency[modelId] = tokensUsed / messageCount;
      }
    }
    return efficiency;
  }

  // ГЕТТЕР: Возвращает статистику использования по моделям ИЗ БАЗЫ ДАННЫХ
  Future<Map<String, Map<String, int>>> getModelUsageStatistics() async { // Метод теперь асинхронный
    try {
      return await _dbService.getAllModelUsageStats();
    } catch (e) {
      debugPrint('Error getting model usage statistics from DB: $e');
      return {};
    }
  }

  // Метод получения статистики по времени ответа (остается без изменений, работает с _sessionData)
  Map<String, dynamic> getResponseTimeStats() {
    if (_sessionData.isEmpty) return {};
    // ... остальная логика без изменений
    final responseTimes =
    _sessionData.map((data) => data['response_time'] as double).toList();
    responseTimes.sort();
    final count = responseTimes.length;
    return {
      'average':
      responseTimes.reduce((a, b) => a + b) / count,
      'median': count.isOdd
          ? responseTimes[count ~/ 2]
          : (responseTimes[(count - 1) ~/ 2] + responseTimes[count ~/ 2]) / 2,
      'min': responseTimes.first,
      'max': responseTimes.last,
    };
  }

  // Метод анализа статистики по длине сообщений (остается без изменений, работает с _sessionData)
  Map<String, dynamic> getMessageLengthStats() {
    if (_sessionData.isEmpty) return {};
    // ... остальная логика без изменений
    final lengths =
    _sessionData.map((data) => data['message_length'] as int).toList();
    final count = lengths.length;
    final total = lengths.reduce((a, b) => a + b);
    return {
      'average_length': total / count,
      'total_characters': total,
      'message_count': count,
    };
  }
}

