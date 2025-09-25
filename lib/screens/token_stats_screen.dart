import 'package:flutter/material.dart';

class TokenStatsScreen extends StatelessWidget {
  const TokenStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Данные-заглушки для статистики
    final Map<String, int> tokenUsageData = {
      'GPT-4': 12500,
      'Claude 3 Sonnet': 8750,
      'Gemini Pro': 15200,
      'Llama 3 70B': 6300,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика Токенов'),
      ),
      body: ListView.builder(
        itemCount: tokenUsageData.length,
        itemBuilder: (context, index) {
          String modelName = tokenUsageData.keys.elementAt(index);
          int tokensUsed = tokenUsageData[modelName]!;
          return ListTile(
            leading: const Icon(Icons.data_usage_outlined),
            title: Text(modelName),
            trailing: Text('$tokensUsed токенов'),
          );
        },
      ),
    );
  }
}
