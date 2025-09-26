import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import 'dart:math'; // For max, min, ceilToDouble

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

  Future<List<Map<String, dynamic>>> _fetchChartData() {
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
              key: ValueKey('${_selectedPeriod}_$_selectedDataType'), 
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
                });
              }
            },
          ),
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
    double calculatedMaxY = 0;

    for (int i = 0; i < statsData.length; i++) {
      final dayData = statsData[i];
      double valueToDisplay;
      switch (_selectedDataType) {
        case ChartDataType.cost:
          valueToDisplay = (dayData['total_cost'] as num?)?.toDouble() ?? 0.0;
          break;
        case ChartDataType.tokens:
          valueToDisplay = (dayData['total_tokens'] as num?)?.toDouble() ?? 0.0;
          break;
        case ChartDataType.messages:
          valueToDisplay = (dayData['message_count'] as num?)?.toDouble() ?? 0.0;
          break;
      }
      if (valueToDisplay > calculatedMaxY) {
        calculatedMaxY = valueToDisplay;
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
    
    double finalMaxY;
    double yAxisInterval;
    bool isIntegerData = _selectedDataType == ChartDataType.tokens || _selectedDataType == ChartDataType.messages;

    if (isIntegerData) {
      if (calculatedMaxY == 0) {
        finalMaxY = 5; 
        yAxisInterval = 1;
      } else {
        finalMaxY = calculatedMaxY.ceilToDouble();
        if (finalMaxY < 5) { 
             yAxisInterval = 1;
             finalMaxY = max(finalMaxY, calculatedMaxY + 1); 
             finalMaxY = max(finalMaxY, 2); // Минимальная высота оси 2, если есть данные
        } else if (finalMaxY < 10) {
          yAxisInterval = 2; 
        } else {
          yAxisInterval = (finalMaxY / 5).ceilToDouble();
        }
      }
      if (yAxisInterval > 0 && finalMaxY > 0) {
        finalMaxY = (finalMaxY / yAxisInterval).ceilToDouble() * yAxisInterval;
      }
      if (finalMaxY < calculatedMaxY) finalMaxY = calculatedMaxY.ceilToDouble();
      if (finalMaxY == 0 && calculatedMaxY > 0) finalMaxY = calculatedMaxY.ceilToDouble();
      if (finalMaxY == 0) finalMaxY = 1; // Если все-таки 0, то хотя бы 1

    } else { // Для ChartDataType.cost
      if (calculatedMaxY == 0) {
        finalMaxY = 0.1; 
        yAxisInterval = 0.02;
      } else {
        yAxisInterval = calculatedMaxY / 4;
        if (yAxisInterval > 0) {
            if (yAxisInterval < 0.001) yAxisInterval = 0.001; // мин интервал
            else if (yAxisInterval < 0.01) yAxisInterval = (yAxisInterval * 1000).ceilToDouble() / 1000;
            else if (yAxisInterval < 0.1) yAxisInterval = (yAxisInterval * 100).ceilToDouble() / 100;
            else if (yAxisInterval < 1) yAxisInterval = (yAxisInterval * 10).ceilToDouble() / 10;
            else yAxisInterval = yAxisInterval.ceilToDouble();
        }
        if (yAxisInterval == 0 && calculatedMaxY > 0) yAxisInterval = calculatedMaxY / 4;
        if (yAxisInterval == 0) yAxisInterval = 0.01;
        finalMaxY = calculatedMaxY;
      }
    }

    if (calculatedMaxY > 0) {
        finalMaxY = finalMaxY * 1.15; 
    } else {
        if (isIntegerData) finalMaxY = max(finalMaxY, 1); 
        else finalMaxY = max(finalMaxY, 0.01); 
    }
    
    if (isIntegerData && yAxisInterval > 0 && finalMaxY > 0) {
        finalMaxY = (finalMaxY / yAxisInterval).ceilToDouble() * yAxisInterval;
    }
     if (finalMaxY == 0 && isIntegerData) finalMaxY = 1; // Последняя проверка для целых
     if (finalMaxY == 0 && !isIntegerData) finalMaxY = 0.1; // и для стоимости
     if (yAxisInterval == 0) yAxisInterval = isIntegerData ? 1 : 0.01;


    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: BarChart(
        BarChartData(
          maxY: finalMaxY,
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
                    final int length = statsData.length;
                    int interval = 1;
                    if (length > 7 && length <= 14) interval = 2;
                    else if (length > 14 && length <= 21) interval = 3;
                    else if (length > 21 && length <= 40) interval = 5;
                    else if (length > 40) interval = (length / 7).ceil(); 
                    if (index % interval == 0 || index == length -1 && index % (interval ~/2) == 0 ) {
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
                reservedSize: 45, 
                interval: yAxisInterval, 
                getTitlesWidget: (double value, TitleMeta meta) {
                    final String displayValue;
                    if (value < 0) return const SizedBox.shrink();
                    if (value > finalMaxY + 1e-9 ) return const SizedBox.shrink(); 

                    if (isIntegerData) {
                      //  Для целых чисел, отображаем только если значение близко к целому кратному интервала
                      if ((value % yAxisInterval).abs() > 0.001 && value != 0 && (yAxisInterval - (value % yAxisInterval)).abs() > 0.001 ) {
                           if (!(yAxisInterval == 1 && (value - value.floor()).abs() < 0.001)) {
                             return const SizedBox.shrink();
                           }
                      }
                      displayValue = value.toInt().toString();
                    } else { 
                         displayValue = value.toStringAsFixed( 
                           (meta.max < 0.1 || yAxisInterval < 0.01) ? 3 :
                           (meta.max < 1 || yAxisInterval < 0.1) ? 2 : 1);
                    }
                    return Text(displayValue, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.left);
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.5), width: 0.5)),
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: false, 
            horizontalInterval: yAxisInterval, 
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 0.5)
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dayData = statsData[group.x.toInt()];
                String dateStr = DateFormat('dd MMM yyyy', 'ru_RU').format(DateTime.parse(dayData['date']));
                String tooltipText = '$dateStr\n';
                switch (_selectedDataType) {
                  case ChartDataType.cost:
                    tooltipText += 'Стоимость: ${rod.toY.toStringAsFixed(3)}';
                    break;
                  case ChartDataType.tokens:
                    tooltipText += 'Токены: ${rod.toY.toInt()}';
                    break;
                  case ChartDataType.messages:
                    tooltipText += 'Сообщения: ${rod.toY.toInt()}';
                    break;
                }
                return BarTooltipItem(
                  tooltipText,
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
            touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
              if (event is FlTapUpEvent && response != null && response.spot != null) {
                final int tappedIndex = response.spot!.touchedBarGroupIndex;
                if (tappedIndex >= 0 && tappedIndex < statsData.length) {
                  final tappedDayData = statsData[tappedIndex];
                  _showDetailsDialog(context, tappedDayData);
                }
              }
            },
          ),
        ),
        swapAnimationDuration: const Duration(milliseconds: 250),
        swapAnimationCurve: Curves.linear,
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> dayData) {
    final String dateFormatted = DateFormat('dd MMMM yyyy г.', 'ru_RU').format(DateTime.parse(dayData['date']));
    final String? modelsRaw = dayData['models_used_raw'];
    final List<String> models = modelsRaw?.split(',').where((m) => m.isNotEmpty).toSet().toList() ?? [];
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Детализация за $dateFormatted', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('Стоимость:', '${(dayData['total_cost'] as num?)?.toDouble()?.toStringAsFixed(3) ?? '0.000'}'),
                _buildDetailRow('Токены:', '${(dayData['total_tokens'] as num?)?.toInt() ?? 0}'),
                _buildDetailRow('Сообщения:', '${(dayData['message_count'] as num?)?.toInt() ?? 0}'),
                if (models.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Использованные модели:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...models.map((model) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                      child: Text('- $model'),
                  )).toList(),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.only(top:8.0),
                    child: Text('Модели не использовались или данные отсутствуют.'),
                  )
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
}
