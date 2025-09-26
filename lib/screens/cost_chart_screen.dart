import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; // Импорт fl_chart
import '../providers/chat_provider.dart';

class CostChartScreen extends StatelessWidget {
  const CostChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('График расходов'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: context.watch<ChatProvider>().dailyUsageStats,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки данных: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет данных для отображения графика.'));
          }

          final List<Map<String, dynamic>> statsData = snapshot.data!;

          // TODO: Преобразовать statsData в формат для fl_chart и отобразить график
          // Например, BarChart или LineChart

          // Заглушка, пока не реализован график:
          return ListView.builder(
            itemCount: statsData.length,
            itemBuilder: (context, index) {
              final dayData = statsData[index];
              return ListTile(
                title: Text(dayData['date']),
                subtitle: Text(
                    'Стоимость: ${dayData['total_cost'].toStringAsFixed(3)}, '
                        'Токены: ${dayData['total_tokens']}, '
                        'Сообщения: ${dayData['message_count']}'
                ),
                trailing: Text(dayData['models_used_raw'] ?? 'N/A'),
              );
            },
          );
        },
      ),
    );
  }
}
