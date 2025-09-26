import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Для форматирования дат, если понадобится
import '../providers/chat_provider.dart';

class CostChartScreen extends StatelessWidget {
  const CostChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('График Расходов по Дням'),
        // backgroundColor: const Color(0xFF262626), // Если нужна консистентность с ChatScreen
        // elevation: 1,
      ),
      // backgroundColor: const Color(0xFF1E1E1E), // Если нужна консистентность с ChatScreen
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: context.watch<ChatProvider>().dailyUsageStats, // Следим за изменениями
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки данных: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет данных для отображения графика.'));
          }

          final List<Map<String, dynamic>> statsData = snapshot.data!;

          // Готовим данные для BarChart
          List<BarChartGroupData> barGroups = [];
          double maxY = 0; // Для определения максимального значения по оси Y

          for (int i = 0; i < statsData.length; i++) {
            final dayData = statsData[i];
            final double cost = (dayData['total_cost'] as num?)?.toDouble() ?? 0.0;
            if (cost > maxY) {
              maxY = cost;
            }
            barGroups.add(
              BarChartGroupData(
                x: i, // Уникальный идентификатор для группы (столбца)
                barRods: [
                  BarChartRodData(
                    toY: cost,
                    color: Colors.blueAccent,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                // Можно добавить показ значения над столбцом, если нужно
                // showingTooltipIndicators: cost > 0 ? [0] : [], 
              ),
            );
          }
          
          // Увеличим maxY для небольшого отступа сверху графика
          maxY = maxY == 0 ? 10 : (maxY * 1.2);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < statsData.length) {
                          // Показываем дату для каждого N-го столбца, чтобы не было слишком плотно
                          if (statsData.length <= 10 || index % (statsData.length ~/ 7).clamp(1,5) == 0) {
                             try {
                               DateTime date = DateTime.parse(statsData[index]['date']);
                               // Форматируем дату, например, "dd/MM"
                               String formattedDate = DateFormat('dd/MM').format(date);
                               return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(formattedDate, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              );
                             } catch (e) {
                               return const SizedBox(); // В случае ошибки парсинга
                             }
                          }
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        // Показываем только некоторые значения, чтобы не перегружать ось
                        if (value == 0 || value == meta.max || value == meta.max / 2) {
                           return Text(
                            value.toStringAsFixed(meta.max > 10 ? 0 : 2), // Меньше знаков после запятой для больших чисел
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            textAlign: TextAlign.left,
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.withOpacity(0.5), width: 0.5),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 0.5,
                    );
                  },
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dayData = statsData[group.x.toInt()];
                      String dateStr = 'Неизвестно';
                      try {
                        dateStr = DateFormat('dd MMM yyyy', 'ru_RU').format(DateTime.parse(dayData['date']));
                      } catch(_){}

                      return BarTooltipItem(
                        '$dateStr\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Стоимость: ${rod.toY.toStringAsFixed(3)}\n',
                            style: const TextStyle(color: Colors.cyan, fontSize: 11),
                          ),
                          TextSpan(
                            text: 'Токены: ${dayData['total_tokens']}\n',
                            style: const TextStyle(color: Colors.yellow, fontSize: 11),
                          ),
                           TextSpan(
                            text: 'Сообщения: ${dayData['message_count']}',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              swapAnimationDuration: const Duration(milliseconds: 250), // Optional
              swapAnimationCurve: Curves.linear, // Optional
            ),
          );
        },
      ),
    );
  }
}
