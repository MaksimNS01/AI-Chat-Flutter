import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class TokenStatsScreen extends StatelessWidget {
  const TokenStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    // modelTokenUsageStats теперь должен возвращать Map<String, Map<String, int>>
    // где внешний ключ - modelId, а внутренний Map - {'tokens': X, 'count': Y}.
    final Map<String, dynamic> tokenUsageByModel = chatProvider.modelTokenUsageStats;

    if (tokenUsageByModel.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Статистика Токенов Моделей'),
        ),
        body: const Center(
          child: Text('Нет данных по использованию токенов. Отправьте сообщения, чтобы собрать статистику.'),
        ),
      );
    }

    // Фильтруем записи, чтобы убедиться, что value является Map (статистика для модели)
    final List<MapEntry<String, dynamic>> modelEntries = tokenUsageByModel.entries
        .where((entry) {
          // Убеждаемся, что значение является Map и содержит ожидаемые числовые значения
          if (entry.value is Map<String, dynamic>) {
            final modelData = entry.value as Map<String, dynamic>;
            return modelData['tokens'] is int && modelData['count'] is int;
          }
          return false;
        })
        .toList();

    if (modelEntries.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Статистика Токенов Моделей'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Нет корректных детальных данных по моделям. Убедитесь, что статистика собирается правильно.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Сортируем модели по общему количеству использованных токенов (по убыванию)
    modelEntries.sort((a, b) {
      final aData = a.value as Map<String, dynamic>; 
      final bData = b.value as Map<String, dynamic>; 
      // Используем правильные ключи: 'tokens' и 'count'
      final aTokens = aData['tokens'] as int? ?? 0;
      final bTokens = bData['tokens'] as int? ?? 0;
      return bTokens.compareTo(aTokens);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика Токенов Моделей'),
      ),
      body: ListView.builder(
        itemCount: modelEntries.length,
        itemBuilder: (context, index) {
          final entry = modelEntries[index];
          final modelId = entry.key;
          final modelData = entry.value as Map<String, dynamic>; 
          // Используем правильные ключи: 'tokens' и 'count'
          final totalTokens = modelData['tokens'] as int? ?? 0;
          final messageCount = modelData['count'] as int? ?? 0;
          
          final modelInfo = chatProvider.availableModels.firstWhere(
            (m) => m['id'] == modelId,
            orElse: () => <String, Object>{'name': modelId}, // Исправлено здесь
          );
          final modelDisplayName = modelInfo['name'] ?? modelId;

          return ListTile(
            leading: const Icon(Icons.insights), 
            title: Text(modelDisplayName),
            subtitle: Text('Сообщений: $messageCount'),
            trailing: Text('$totalTokens токенов'),
          );
        },
      ),
    );
  }
}
