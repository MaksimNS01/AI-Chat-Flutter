import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';

// Перечисления для выбора типа данных и периода
enum ChartDataType { cost, tokens, messages }
enum DataPeriod { days7, days30, days90 }

class CostChartScreen extends StatefulWidget {
  const CostChartScreen({super.key});

  @override
  State<CostChartScreen> createState() => _CostChartScreenState();
}

class _CostChartScreenState extends State<CostChartScreen> {
  ChartDataType _selectedDataType = ChartDataType.cost;
  DataPeriod _selectedPeriod = DataPeriod.days30;

  // Метод для получения числового значения лимита дней
  int get _daysLimit {
    switch (_selectedPeriod) {
      case DataPeriod.days7:
        return 7;
      case DataPeriod.days30:
        return 30;
      case DataPeriod.days90:
        return 90;
    }
  }

  // Метод для получения данных из провайдера с учетом лимита
  Future<List<Map<String, dynamic>>> _fetchChartData() {
    // ChatProvider будет изменен для приема daysLimit
    return context.read<ChatProvider>().getDailyUsageStatsWithLimit(_daysLimit);
  }

  String _getChartDataTypeName(ChartDataType type) {
    switch (type) {
      case ChartDataType.cost:
        return 'Стоимость';
      case ChartDataType.tokens:
        return 'Токены';
      case ChartDataType.messages:
        return 'Сообщения';
    }
  }

   String _getDataPeriodName(DataPeriod period) {
    switch (period) {
      case DataPeriod.days7:
        return '7 дней';
      case DataPeriod.days30:
        return '30 дней';
      case DataPeriod.days90:
        return '90 дней';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('График Расходов'),
      ),
      body: Column(
        children: [
          _buildControls(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              // Используем _fetchChartData, который будет вызывать метод с лимитом
              // future: context.watch<ChatProvider>().getDailyUsageStatsWithLimit(_daysLimit),
              // Для FutureBuilder лучше использовать ключ, чтобы он перестраивался при смене future
              key: ValueKey('${_selectedPeriod}_$_selectedDataType'), // Ключ для перестройки FutureBuilder
              future: _fetchChartData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка загрузки данных: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Нет данных для отображения графика за выбранный период.'));
                }

                final List<Map<String, dynamic>> statsData = snapshot.data!;
                return _buildChart(statsData);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Выбор типа данных
          DropdownButton<ChartDataType>(
            value: _selectedDataType,
            items: ChartDataType.values.map((type) {
              return DropdownMenuItem<ChartDataType>(
                value: type,
                child: Text(_getChartDataTypeName(type)),
              );
            }).toList(),
            onChanged: (ChartDataType? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedDataType = newValue;
                  // FutureBuilder перестроится из-за смены ключа и вызовет _fetchChartData
                });
              }
            },
          ),
          // Выбор периода
          DropdownButton<DataPeriod>(
            value: _selectedPeriod,
            items: DataPeriod.values.map((period) {
              return DropdownMenuItem<DataPeriod>(
                value: period,
                child: Text(_getDataPeriodName(period)),
              );
            }).toList(),
            onChanged: (DataPeriod? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedPeriod = newValue;
                  // FutureBuilder перестроится из-за смены ключа и вызовет _fetchChartData
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> statsData) {
    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    String yAxisLabel = '';

    for (int i = 0; i < statsData.length; i++) {
      final dayData = statsData[i];
      double valueToDisplay;

      switch (_selectedDataType) {
        case ChartDataType.cost:
          valueToDisplay = (dayData['total_cost'] as num?)?.toDouble() ?? 0.0;
          yAxisLabel = 'Стоимость';
          break;
        case ChartDataType.tokens:
          valueToDisplay = (dayData['total_tokens'] as num?)?.toDouble() ?? 0.0;
          yAxisLabel = 'Токены';
          break;
        case ChartDataType.messages:
          valueToDisplay = (dayData['message_count'] as num?)?.toDouble() ?? 0.0;
          yAxisLabel = 'Сообщения';
          break;
      }

      if (valueToDisplay > maxY) {
        maxY = valueToDisplay;
      }
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: valueToDisplay,
              color: _selectedDataType == ChartDataType.cost ? Colors.blueAccent : 
                     (_selectedDataType == ChartDataType.tokens ? Colors.orangeAccent : Colors.greenAccent),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    maxY = maxY == 0 ? 10 : (maxY * 1.2); // Отступ сверху

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
                    if (statsData.length <= 10 || index % (statsData.length ~/ 7).clamp(1,5) == 0) {
                      try {
                        DateTime date = DateTime.parse(statsData[index]['date']);
                        String formattedDate = DateFormat('dd/MM').format(date);
                        return SideTitleWidget(
                          axisSide: meta.axisSide, space: 4,
                          child: Text(formattedDate, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        );
                      } catch (e) { return const SizedBox(); }
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45, // Может понадобиться больше места для разных значений
                getTitlesWidget: (double value, TitleMeta meta) {
                   if (value == 0 || value == meta.max || value == meta.max / 2 ) {
                       final String displayValue;
                        if (_selectedDataType == ChartDataType.cost) {
                          displayValue = value.toStringAsFixed(meta.max > 10 ? 1 : 2);
                        } else { // Для токенов и сообщений - целые числа
                          displayValue = value.toInt().toString();
                        }
                        return Text(displayValue, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.left);
                   }
                   return const SizedBox();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.5), width: 0.5)),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 0.5)),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dayData = statsData[group.x.toInt()];
                String dateStr = DateFormat('dd MMM yyyy', 'ru_RU').format(DateTime.parse(dayData['date']));
                
                String tooltipText = '$dateStr\n';
                TextStyle valueStyle = const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold);

                switch (_selectedDataType) {
                  case ChartDataType.cost:
                    tooltipText += 'Стоимость: ${rod.toY.toStringAsFixed(3)}';
                    valueStyle = const TextStyle(color: Colors.cyan, fontSize: 11);
                    break;
                  case ChartDataType.tokens:
                    tooltipText += 'Токены: ${rod.toY.toInt()}';
                     valueStyle = const TextStyle(color: Colors.yellow, fontSize: 11);
                    break;
                  case ChartDataType.messages:
                    tooltipText += 'Сообщения: ${rod.toY.toInt()}';
                     valueStyle = const TextStyle(color: Colors.greenAccent, fontSize: 11);
                    break;
                }

                return BarTooltipItem(
                  tooltipText,
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  // children: [], // Если основной текст уже включает значение
                );
              },
            ),
            // --- НАЧАЛО: Логика для детальной информации при нажатии ---
            touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
              if (event is FlTapUpEvent && response != null && response.spot != null) {
                final int tappedIndex = response.spot!.touchedBarGroupIndex;
                if (tappedIndex >= 0 && tappedIndex < statsData.length) {
                  final tappedDayData = statsData[tappedIndex];
                  _showDetailsDialog(context, tappedDayData);
                }
              }
            },
            // --- КОНЕЦ: Логика для детальной информации при нажатии ---
          ),
        ),
        swapAnimationDuration: const Duration(milliseconds: 250),
        swapAnimationCurve: Curves.linear,
      ),
    );
  }

  // --- НАЧАЛО: Диалог с детальной информацией ---
  void _showDetailsDialog(BuildContext context, Map<String, dynamic> dayData) {
    final String dateFormatted = DateFormat('dd MMMM yyyy г.', 'ru_RU').format(DateTime.parse(dayData['date']));
    final String? modelsRaw = dayData['models_used_raw'];
    final List<String> models = modelsRaw?.split(',').where((m) => m.isNotEmpty).toSet().toList() ?? []; // Уникальные модели

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // backgroundColor: const Color(0xFF2C2C2C),
          title: Text('Детализация за $dateFormatted', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('Стоимость:', '${(dayData['total_cost'] as num?)?.toDouble() ?? 0.0}'),
                _buildDetailRow('Токены:', '${(dayData['total_tokens'] as num?)?.toInt() ?? 0}'),
                _buildDetailRow('Сообщения:', '${(dayData['message_count'] as num?)?.toInt() ?? 0}'),
                if (models.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Использованные модели:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...models.map((model) => Text('- $model')).toList(),
                ] else ...[
                  const Text('Модели не использовались или данные отсутствуют.')
                ]
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Закрыть'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
 // --- КОНЕЦ: Диалог с детальной информацией ---
}
