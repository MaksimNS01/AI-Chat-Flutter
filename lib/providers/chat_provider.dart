// Импорт библиотеки для работы с JSON
import 'dart:convert';
// Импорт библиотеки для работы с файловой системой
import 'dart:io';
// Импорт основных классов Flutter
import 'package:flutter/foundation.dart';
// Импорт пакета для получения путей к директориям
import 'package:path_provider/path_provider.dart';
// Импорт SharedPreferences для хранения настроек
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Импорт модели сообщения
import '../models/message.dart';
// Импорт клиента для работы с API
import '../api/openrouter_client.dart';
// Импорт сервиса для работы с базой данных
import '../services/database_service.dart';
// Импорт сервиса для аналитики
import '../services/analytics_service.dart';
// Импорт ключей настроек из settings_screen
import '../screens/settings_screen.dart'; // Для selectedProviderKey, openRouterApiKeyId, etc.

// Основной класс провайдера для управления состоянием чата
class ChatProvider with ChangeNotifier {
  // Клиент для работы с API (не final, чтобы можно было пересоздать)
  OpenRouterClient _api = OpenRouterClient();
  // Список сообщений чата
  final List<ChatMessage> _messages = [];
  // Логи для отладки
  final List<String> _debugLogs = [];
  // Список доступных моделей
  List<Map<String, dynamic>> _availableModels = [];
  // Текущая выбранная модель
  String? _currentModel;
  // Баланс пользователя
  String _balance = '\$0.00';
  // Флаг загрузки
  bool _isLoading = false;

  // Настройки API
  String _selectedProvider = providerOpenRouter; // Значение по умолчанию
  String _openRouterApiKey = '';
  String _vseGptApiKey = '';


  // Метод для логирования сообщений
  void _log(String message) {
    _debugLogs.add('${DateTime.now()}: $message');
    debugPrint(message);
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<Map<String, dynamic>> get availableModels => _availableModels;
  String? get currentModel => _currentModel;
  String get balance => _balance;
  bool get isLoading => _isLoading;
  String? get baseUrl => _api.baseUrl;

  ChatProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    try {
      _log('Initializing provider...');
      await _loadApiSettings(); // Загрузка настроек API
      // _api должен переинициализироваться или использовать обновленный dotenv
      // OpenRouterClient() при создании должен подхватить ключ из dotenv.env
      _api = OpenRouterClient(); 

      await _loadModels();
      _log('Models loaded: ${_availableModels.length}');
      await _loadBalance();
      _log('Balance loaded: $_balance');
      await _loadHistory();
      _log('History loaded: ${_messages.length} messages');
    } catch (e, stackTrace) {
      _log('Error initializing provider: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedProvider = prefs.getString(selectedProviderKey) ?? providerOpenRouter;
    _openRouterApiKey = prefs.getString(openRouterApiKeyId) ?? '';
    _vseGptApiKey = prefs.getString(vseGptApiKeyId) ?? '';

    _log('API settings loaded: Provider: $_selectedProvider');
    _log('OpenRouter Key Loaded: ${_openRouterApiKey.isNotEmpty}');
    _log('VSEGPT Key Loaded: ${_vseGptApiKey.isNotEmpty}');

    // Обновляем dotenv на случай, если OpenRouterClient читает его при каждом запросе или при создании
    // В settings_screen это уже делается при сохранении, но здесь для инициализации полезно
    if (_selectedProvider == providerOpenRouter) {
      dotenv.env['OPENROUTER_API_KEY'] = _openRouterApiKey;
    } else if (_selectedProvider == providerVseGpt) {
      // Предполагаем, что VSEGPT также будет использовать OPENROUTER_API_KEY в dotenv для OpenRouterClient
      // или что OpenRouterClient будет адаптирован для работы с разными ключами/провайдерами.
      // Если VSEGPT требует совершенно другого клиента, логика здесь усложнится.
      dotenv.env['OPENROUTER_API_KEY'] = _vseGptApiKey;
    }
     _log('Dotenv OPENROUTER_API_KEY set to: ${dotenv.env['OPENROUTER_API_KEY']}');
  }

  // Вызывается из SettingsScreen при обновлении настроек
  Future<void> apiSettingsUpdated() async {
    _log('API settings updated notification received.');
    await _loadApiSettings();
    _api = OpenRouterClient(); // Пересоздаем клиент, чтобы он использовал новый ключ из dotenv
    
    // Перезагружаем данные, зависящие от API
    await _loadModels();
    await _loadBalance();
    notifyListeners(); // Уведомляем слушателей об изменениях (например, новый список моделей)
  }

  Future<void> _loadModels() async {
    // ... (существующий код без изменений)
    try {
      // Получение списка моделей из API
      _availableModels = await _api.getModels();
      // Сортировка моделей по имени по возрастанию
      _availableModels
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      // Установка модели по умолчанию, если она не выбрана
      if (_availableModels.isNotEmpty && _currentModel == null) {
        _currentModel = _availableModels[0]['id'];
      }
      // Уведомление слушателей об изменениях
      notifyListeners();
    } catch (e) {
      // Логирование ошибок загрузки моделей
      _log('Error loading models: $e');
      _availableModels = []; // Очищаем модели в случае ошибки
      _currentModel = null;
      notifyListeners();
    }
  }

  Future<void> _loadBalance() async {
    // ... (существующий код без изменений)
    try {
      // Получение баланса из API
      _balance = await _api.getBalance();
      // Уведомление слушателей об изменениях
      notifyListeners();
    } catch (e) {
      // Логирование ошибок загрузки баланса
      _log('Error loading balance: $e');
      _balance = '\$0.00 (Error)'; // Показываем ошибку в балансе
      notifyListeners();
    }
  }

  final DatabaseService _db = DatabaseService();
  final AnalyticsService _analytics = AnalyticsService();

  Future<void> _loadHistory() async {
    // ... (существующий код без изменений)
    try {
      // Получение сообщений из базы данных
      final messages = await _db.getMessages();
      // Очистка текущего списка и добавление новых сообщений
      _messages.clear();
      _messages.addAll(messages);
      // Уведомление слушателей об изменениях
      notifyListeners();
    } catch (e) {
      // Логирование ошибок загрузки истории
      _log('Error loading history: $e');
    }
  }

  Future<void> _saveMessage(ChatMessage message) async {
    // ... (существующий код без изменений)
     try {
      // Сохранение сообщения в базу данных
      await _db.saveMessage(message);
    } catch (e) {
      // Логирование ошибок сохранения сообщения
      _log('Error saving message: $e');
    }
  }

  Future<void> sendMessage(String content, {bool trackAnalytics = true}) async {
    // ... (существующий код sendMessage)
    // Убедимся, что _api использует актуальный ключ, если он читает dotenv не при каждом запросе
    // Однако, _api уже пересоздается в apiSettingsUpdated и _initializeProvider
    // Ключевой момент - _api.sendMessage должен использовать корректный ключ
    // ...
    // Проверка на пустое сообщение или отсутствие модели
    if (content.trim().isEmpty || _currentModel == null) return;

    // Установка флага загрузки
    _isLoading = true;
    // Уведомление слушателей об изменениях
    notifyListeners();

    try {
      // Обеспечение правильного кодирования сообщения
      content = utf8.decode(utf8.encode(content));

      // Добавление сообщения пользователя
      final userMessage = ChatMessage(
        content: content,
        isUser: true,
        modelId: _currentModel,
      );
      _messages.add(userMessage);
      // Уведомление слушателей об изменениях
      notifyListeners();

      // Сохранение сообщения пользователя
      await _saveMessage(userMessage);

      // Запись времени начала отправки
      final startTime = DateTime.now();

      // Отправка сообщения в API
      final response = await _api.sendMessage(content, _currentModel!);
      // Логирование ответа API
      _log('API Response: $response');

      // Расчет времени ответа
      final responseTime =
          DateTime.now().difference(startTime).inMilliseconds / 1000;

      if (response.containsKey('error')) {
        // Добавление сообщения об ошибке
        final errorMessage = ChatMessage(
          content: utf8.decode(utf8.encode('Error: ${response['error']}')),
          isUser: false,
          modelId: _currentModel,
        );
        _messages.add(errorMessage);
        await _saveMessage(errorMessage);
      } else if (response.containsKey('choices') &&
          response['choices'] is List &&
          response['choices'].isNotEmpty &&
          response['choices'][0] is Map &&
          response['choices'][0].containsKey('message') &&
          response['choices'][0]['message'] is Map &&
          response['choices'][0]['message'].containsKey('content')) {
        // Добавление ответа AI
        final aiContent = utf8.decode(utf8.encode(
          response['choices'][0]['message']['content'] as String,
        ));
        // Получение количества использованных токенов
        final tokens = response['usage']?['total_tokens'] as int? ?? 0;

        // Трекинг аналитики, если включен
        if (trackAnalytics) {
          _analytics.trackMessage(
            model: _currentModel!,
            messageLength: content.length,
            responseTime: responseTime,
            tokensUsed: tokens,
          );
        }

        // Создание и добавление сообщения AI
        // Получение количества токенов из ответа
        final promptTokens = response['usage']?['prompt_tokens'] ?? 0;
        final completionTokens = response['usage']?['completion_tokens'] ?? 0;

        final totalCost = response['usage']?['total_cost'];
        
        Map<String, dynamic>? modelData;
        if (_availableModels.any((m) => m['id'] == _currentModel)) {
            modelData = _availableModels.firstWhere((m) => m['id'] == _currentModel);
        }


        // Расчет стоимости запроса
        final cost = (totalCost == null && modelData != null)
            ? ((promptTokens *
                    (double.tryParse(modelData['pricing']?['prompt']?.toString() ?? '0.0') ?? 0.0)) +
                (completionTokens *
                    (double.tryParse(modelData['pricing']?['completion']?.toString() ?? '0.0') ?? 0.0)))
            : (totalCost ?? 0.0);


        // Логирование ответа API
        _log('Cost Response: $cost');

        final aiMessage = ChatMessage(
          content: aiContent,
          isUser: false,
          modelId: _currentModel,
          tokens: tokens,
          cost: cost,
        );
        _messages.add(aiMessage);
        // Сохранение сообщения AI
        await _saveMessage(aiMessage);

        // Обновление баланса после успешного сообщения
        await _loadBalance();
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      // Логирование ошибок отправки сообщения
      _log('Error sending message: $e');
      // Добавление сообщения об ошибке
      final errorMessage = ChatMessage(
        content: utf8.decode(utf8.encode('Error: $e')),
        isUser: false,
        modelId: _currentModel,
      );
      _messages.add(errorMessage);
      // Сохранение сообщения об ошибке
      await _saveMessage(errorMessage);
    } finally {
      // Сброс флага загрузки
      _isLoading = false;
      // Уведомление слушателей об изменениях
      notifyListeners();
    }
  }

  void setCurrentModel(String modelId) {
    _currentModel = modelId;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _messages.clear();
    await _db.clearHistory();
    _analytics.clearData();
    notifyListeners();
  }

  Future<String> exportLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'chat_logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt';
    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    buffer.writeln('=== Debug Logs ===\n');
    for (final log in _debugLogs) {
      buffer.writeln(log);
    }

    buffer.writeln('\n=== Chat Logs ===\n');
    buffer.writeln('Generated: ${now.toString()}\n');

    for (final message in _messages) {
      buffer.writeln('${message.isUser ? "User" : "AI"} (${message.modelId}):');
      buffer.writeln(message.content);
      if (message.tokens != null) {
        buffer.writeln('Tokens: ${message.tokens}');
      }
      buffer.writeln('Time: ${message.timestamp}');
      buffer.writeln('---\n');
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> exportMessagesAsJson() async {
    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'chat_history_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json';
    final file = File('${directory.path}/$fileName');

    final List<Map<String, dynamic>> messagesJson =
        _messages.map((message) => message.toJson()).toList();

    await file.writeAsString(jsonEncode(messagesJson));
    return file.path;
  }

  String formatPricing(double pricing) {
    return _api.formatPricing(pricing);
  }

  Future<Map<String, dynamic>> exportHistory() async {
    final dbStats = await _db.getStatistics();
    final analyticsStats = _analytics.getStatistics();
    final sessionData = _analytics.exportSessionData();
    final modelEfficiency = _analytics.getModelEfficiency();
    final responseTimeStats = _analytics.getResponseTimeStats();
    final messageLengthStats = _analytics.getMessageLengthStats();

    return {
      'database_stats': dbStats,
      'analytics_stats': analyticsStats,
      'session_data': sessionData,
      'model_efficiency': modelEfficiency,
      'response_time_stats': responseTimeStats,
      'message_length_stats': messageLengthStats,
    };
  }
}
