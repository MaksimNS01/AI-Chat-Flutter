import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

// Ключи для SharedPreferences
const String selectedProviderKey = 'selected_api_provider';
const String openRouterApiKeyId = 'openrouter_api_key';
const String vseGptApiKeyId = 'vsegpt_api_key';

// Идентификаторы провайдеров
const String providerOpenRouter = 'OpenRouter';
const String providerVseGpt = 'VSEGPT';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _openRouterApiKeyController = TextEditingController();
  final TextEditingController _vseGptApiKeyController = TextEditingController();
  String _selectedProvider = providerOpenRouter; // Провайдер по умолчанию

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvider = prefs.getString(selectedProviderKey) ?? providerOpenRouter;
      _openRouterApiKeyController.text = prefs.getString(openRouterApiKeyId) ?? '';
      _vseGptApiKeyController.text = prefs.getString(vseGptApiKeyId) ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedProviderKey, _selectedProvider);
    await prefs.setString(openRouterApiKeyId, _openRouterApiKeyController.text);
    await prefs.setString(vseGptApiKeyId, _vseGptApiKeyController.text);

    // Обновляем dotenv в зависимости от выбранного провайдера.
    // Это предположение, что OpenRouterClient использует dotenv.env['OPENROUTER_API_KEY']
    // и что VSEGPT (если бы он использовал тот же клиент) тоже ожидал бы ключ здесь.
    if (_selectedProvider == providerOpenRouter) {
      dotenv.env['OPENROUTER_API_KEY'] = _openRouterApiKeyController.text;
    } else if (_selectedProvider == providerVseGpt) {
      // Если VSEGPT использует другой ключ в dotenv или другой клиент, это нужно будет адаптировать.
      // Пока предполагаем, что он может использовать тот же ключ dotenv для OpenRouterClient.
      dotenv.env['OPENROUTER_API_KEY'] = _vseGptApiKeyController.text;
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки сохранены!')),
      );
      // Уведомляем ChatProvider об изменениях
      Provider.of<ChatProvider>(context, listen: false).apiSettingsUpdated();
    }
  }

  @override
  void dispose() {
    _openRouterApiKeyController.dispose();
    _vseGptApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Text('Выбор Провайдера API', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Провайдер',
                border: OutlineInputBorder(),
              ),
              items: [providerOpenRouter, providerVseGpt]
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedProvider = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            Text('API Ключи', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _openRouterApiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Ключ OpenRouter',
                hintText: 'Введите ваш API ключ для OpenRouter',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vseGptApiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Ключ VSEGPT',
                hintText: 'Введите ваш API ключ для VSEGPT',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Сохранить настройки'),
            ),
          ],
        ),
      ),
    );
  }
}
