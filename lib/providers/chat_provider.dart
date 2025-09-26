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
// Импорт ключей настроек и констант провайдеров из settings_screen.dart
import '../screens/settings_screen.dart'; 

// Основной класс провайдера для управления состоянием чата
class ChatProvider with ChangeNotifier {
  late OpenRouterClient _api; // Изменено: используется late для отложенной инициализации
  final List<ChatMessage> _messages = [];
  final List<String> _debugLogs = [];
  List<Map<String, dynamic>> _availableModels = [];
  String? _currentModel;
  String _balance = '\$0.00';
  bool _isLoading = false;

  String _selectedProvider = providerOpenRouter;
  String _apiKey = '';

  final DatabaseService _db = DatabaseService();
  final AnalyticsService _analytics = AnalyticsService();

  void _log(String message) {
    _debugLogs.add('${DateTime.now()}: $message');
    debugPrint(message);
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<Map<String, dynamic>> get availableModels => _availableModels;
  String? get currentModel => _currentModel;
  String get balance => _balance;
  bool get isLoading => _isLoading;
  String? get baseUrl => _api.baseUrl; // Доступ к _api только после инициализации

  Map<String, dynamic> get modelTokenUsageStats {
    final stats = _analytics.getModelUsageStatistics();
    return stats; 
  }

  ChatProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    try {
      _log('Initializing provider...');
      await _loadApiSettings(); 
      _api = OpenRouterClient(); // Инициализация _api ПОСЛЕ загрузки настроек
      _log('OpenRouterClient instantiated after API settings loaded.');
      await _loadModels();
      _log('Models loaded: ${_availableModels.length}');
      await _loadBalance();
      _log('Balance loaded: $_balance');
      await _loadHistory();
      _log('History loaded: ${_messages.length} messages');
    } catch (e, stackTrace) {
      _log('Error initializing provider: $e');
      _log('Stack trace: $stackTrace');
      // Если _api не инициализировано, методы типа _loadModels могут вызвать ошибку late initialization
      // Добавим обработку, чтобы приложение не падало, если ключ не загружен и _api не создан
      _availableModels = [];
      _currentModel = null;
      _balance = 'Error';
      notifyListeners(); 
    }
  }

  Future<void> _loadApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedProvider = prefs.getString(activeProviderKey) ?? providerOpenRouter;
    _apiKey = prefs.getString(apiKeyKey) ?? '';

    if (_apiKey.isNotEmpty) {
      dotenv.env['OPENROUTER_API_KEY'] = _apiKey;
      _log('API key for $_selectedProvider loaded into dotenv. Key: $_apiKey');
    } else {
      _log('API key not found in SharedPreferences or is empty.');
      dotenv.env.remove('OPENROUTER_API_KEY');
    }
  }

  Future<void> apiSettingsUpdated() async {
    _log('API settings updated notification received.');
    await _loadApiSettings(); 
    _api = OpenRouterClient(); 
    _log('OpenRouterClient re-instantiated after API settings update.');
    await _loadModels();    
    await _loadBalance();   
    notifyListeners();      
  }

  Future<void> _loadModels() async {
    if (!(_apiKey.isNotEmpty)) { // Проверка, что _apiKey загружен
      _log('Cannot load models: API key is missing.');
      _availableModels = [];
      _currentModel = null;
      notifyListeners();
      return;
    }
    try {
      _availableModels = await _api.getModels();
      _availableModels.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      if (_availableModels.isNotEmpty && _currentModel == null) {
        _currentModel = _availableModels[0]['id'];
      }
      notifyListeners();
    } catch (e) {
      _log('Error loading models: $e');
      _availableModels = [];
      _currentModel = null;
      notifyListeners();
    }
  }

  Future<void> _loadBalance() async {
     if (!(_apiKey.isNotEmpty)) { // Проверка, что _apiKey загружен
      _log('Cannot load balance: API key is missing.');
      _balance = '\$0.00 (API Key Missing)';
      notifyListeners();
      return;
    }
    try {
      _balance = await _api.getBalance();
      notifyListeners();
    } catch (e) {
      _log('Error loading balance: $e');
      _balance = '\$0.00 (Error)';
      notifyListeners();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final loadedMessages = await _db.getMessages();
      _messages.clear();
      _messages.addAll(loadedMessages);
      notifyListeners();
    } catch (e) {
      _log('Error loading history: $e');
    }
  }

  Future<void> _saveMessage(ChatMessage message) async {
    try {
      await _db.saveMessage(message);
    } catch (e) {
      _log('Error saving message: $e');
    }
  }

  Future<void> sendMessage(String content, {bool trackAnalytics = true}) async {
    if (!(_apiKey.isNotEmpty)) { // Проверка, что _apiKey загружен
      _log('Cannot send message: API key is missing.');
       final errorMessage = ChatMessage(content: 'Ошибка: API ключ не настроен или отсутствует.', isUser: false, modelId: _currentModel);
      _messages.add(errorMessage);
      // await _saveMessage(errorMessage); // Не сохраняем системные ошибки отсутствия ключа в историю
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (content.trim().isEmpty || _currentModel == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      content = utf8.decode(utf8.encode(content));
      final userMessage = ChatMessage(content: content, isUser: true, modelId: _currentModel);
      _messages.add(userMessage);
      notifyListeners();
      await _saveMessage(userMessage);

      final startTime = DateTime.now();
      final response = await _api.sendMessage(content, _currentModel!);
      final responseTime = DateTime.now().difference(startTime).inMilliseconds / 1000;

      if (response.containsKey('error')) {
        final errorMessageText = response['error'] is Map ? response['error']['message'] ?? response['error'].toString() : response['error'].toString();
        final errorMessage = ChatMessage(content: utf8.decode(utf8.encode('Error: $errorMessageText')), isUser: false, modelId: _currentModel);
        _messages.add(errorMessage);
        await _saveMessage(errorMessage);
      } else if (response.containsKey('choices') &&
          response['choices'] is List &&
          response['choices'].isNotEmpty &&
          response['choices'][0] is Map &&
          response['choices'][0].containsKey('message') &&
          response['choices'][0]['message'] is Map &&
          response['choices'][0]['message'].containsKey('content')) {
        final aiContent = utf8.decode(utf8.encode(response['choices'][0]['message']['content'] as String));
        final tokensInResponse = response['usage']?['total_tokens'] as int? ?? 0;

        if (trackAnalytics) {
          _analytics.trackMessage(model: _currentModel!, messageLength: content.length, responseTime: responseTime, tokensUsed: tokensInResponse);
        }

        final promptTokens = response['usage']?['prompt_tokens'] ?? 0;
        final completionTokens = response['usage']?['completion_tokens'] ?? 0;
        final totalCost = response['usage']?['total_cost'];
        Map<String, dynamic>? modelDataFromApi;
        if (_availableModels.any((m) => m['id'] == _currentModel)) {
          modelDataFromApi = _availableModels.firstWhere((m) => m['id'] == _currentModel);
        }

        final cost = (totalCost == null && modelDataFromApi != null)
            ? ((promptTokens * (double.tryParse(modelDataFromApi['pricing']?['prompt']?.toString() ?? '0.0') ?? 0.0)) +
               (completionTokens * (double.tryParse(modelDataFromApi['pricing']?['completion']?.toString() ?? '0.0') ?? 0.0)))
            : (totalCost ?? 0.0);

        final aiMessage = ChatMessage(content: aiContent, isUser: false, modelId: _currentModel, tokens: tokensInResponse, cost: cost);
        _messages.add(aiMessage);
        await _saveMessage(aiMessage);
        await _loadBalance();
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      _log('Error sending message: $e');
      final errorMessage = ChatMessage(content: utf8.decode(utf8.encode('Error: $e')), isUser: false, modelId: _currentModel);
      _messages.add(errorMessage);
      await _saveMessage(errorMessage);
    } finally {
      _isLoading = false;
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
    final fileName = 'chat_logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt';
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
    final fileName = 'chat_history_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json';
    final file = File('${directory.path}/$fileName');
    final List<Map<String, dynamic>> messagesJson = _messages.map((message) => message.toJson()).toList();
    await file.writeAsString(jsonEncode(messagesJson));
    return file.path;
  }

  String formatPricing(double pricing) {
    // Проверка, инициализирован ли _api, перед его использованием
    if (this.isInitialized()) { // Предполагается, что isInitialized() - это геттер, который вы добавите
        return _api.formatPricing(pricing);
    }
    return "API not ready"; // Или другое значение по умолчанию
  }
   // Добавьте этот геттер, чтобы проверить, был ли _api инициализирован
  bool isInitialized() {
    // Простой способ проверить - посмотреть, не пустой ли _apiKey, 
    // так как _api инициализируется только если _apiKey есть.
    // Более надежно - проверять сам _api, если он может быть null или иметь состояние.
    // В данном случае, так как _api - late, обращение к нему до инициализации вызовет ошибку.
    // Поэтому, проверка _apiKey косвенно говорит об инициализации _api.
    return _apiKey.isNotEmpty; 
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
      'model_usage_detailed': _analytics.getModelUsageStatistics(), 
      'response_time_stats': responseTimeStats,
      'message_length_stats': messageLengthStats,
    };
  }
}
