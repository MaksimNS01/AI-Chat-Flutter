import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class TokenStatsScreen extends StatelessWidget {
  const TokenStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false); // listen: false is often good for one-off reads in FutureBuilder

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика Токенов Моделей'),
      ),
      body: FutureBuilder<Map<String, Map<String, int>>>(
        future: chatProvider.modelTokenUsageStats, // Используем Future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Ошибка загрузки статистики: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Нет данных по использованию токенов. Отправьте сообщения, чтобы собрать статистику.'),
            );
          }

          final Map<String, Map<String, int>> tokenUsageByModel = snapshot.data!;

          // Фильтруем записи (хотя с новым типом это может быть излишним, если данные всегда корректны)
          // Теперь внутренний Map уже Map<String, int>, так что проверка и каст упрощаются.
          final List<MapEntry<String, Map<String, int>>> modelEntries = tokenUsageByModel.entries
              .where((entry) {
                // Убеждаемся, что значение является Map и содержит ожидаемые числовые значения
                // entry.value теперь Map<String, int>
                final modelData = entry.value; 
                return modelData.containsKey('tokens') && 
                       modelData.containsKey('count') && 
                       modelData['tokens'] is int && 
                       modelData['count'] is int;
              })
              .toList();

          if (modelEntries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Нет корректных детальных данных по моделям. Убедитесь, что статистика собирается правильно.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Сортируем модели по общему количеству использованных токенов (по убыванию)
          modelEntries.sort((a, b) {
            final aData = a.value; // Теперь это Map<String, int>
            final bData = b.value; // Теперь это Map<String, int>
            final aTokens = aData['tokens'] ?? 0;
            final bTokens = bData['tokens'] ?? 0;
            return bTokens.compareTo(aTokens);
          });

          // Consumer для доступа к chatProvider.availableModels, если он нужен здесь
          // Если availableModels не меняется часто, можно получить его один раз вне FutureBuilder
          // или передать как параметр, если TokenStatsScreen становится StatefulWidget.
          // Для простоты пока оставим так, но это может вызывать перестроения.
          final availableModels = Provider.of<ChatProvider>(context).availableModels;

          return ListView.builder(
            itemCount: modelEntries.length,
            itemBuilder: (context, index) {
              final entry = modelEntries[index];
              final modelId = entry.key;
              final modelData = entry.value; // Теперь это Map<String, int>
              
              final totalTokens = modelData['tokens'] ?? 0;
              final messageCount = modelData['count'] ?? 0;
              
              final modelInfo = availableModels.firstWhere(
                (m) => m['id'] == modelId,
                orElse: () => <String, Object>{'name': modelId, 'id': modelId}, // Добавим id для консистентности
              );
              final modelDisplayName = modelInfo['name'] as String? ?? modelId;

              return ListTile(
                leading: const Icon(Icons.insights), 
                title: Text(modelDisplayName),
                subtitle: Text('Сообщений: $messageCount'),
                trailing: Text('$totalTokens токенов'),
              );
            },
          );
        },
      ),
    );
  }
}
