import 'package:flutter/material.dart';

class ExpensesChartScreen extends StatelessWidget {
  const ExpensesChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('График Расходов'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.show_chart, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 20),
              Text(
                'Здесь будет график расходов по дням.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                '(Интеграция с библиотекой графиков будет добавлена позже)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
