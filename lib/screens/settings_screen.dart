import 'dart:math'; // For PIN generation
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart'; // Assuming ChatProvider is still relevant

// Ключи для SharedPreferences
const String apiKeyKey = 'api_key';
const String pinKey = 'pin_code';
const String activeProviderKey = 'active_api_provider'; // To store which provider is active

// Идентификаторы провайдеров (можно оставить, если используются где-то еще, или удалить если нет)
const String providerOpenRouter = 'OpenRouter';
const String providerVseGpt = 'VSEGPT';

// Префиксы ключей
const String openRouterPrefix = 'sk-or-v1-';
const String vseGptPrefix = 'sk-or-vv-';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveApiKeyAndProceed() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final apiKey = _apiKeyController.text.trim();
    String? determinedProvider;

    if (apiKey.isEmpty) {
      _showError('API ключ не может быть пустым.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (apiKey.startsWith(openRouterPrefix)) {
      determinedProvider = providerOpenRouter;
    } else if (apiKey.startsWith(vseGptPrefix)) {
      determinedProvider = providerVseGpt;
    } else {
      _showError('Неверный формат API ключа. Ключ должен начинаться с \'$openRouterPrefix\' или \'$vseGptPrefix\'.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // --- ЗАГЛУШКА для проверки ключа и баланса ---
    // В будущем здесь должен быть реальный API вызов для проверки ключа и баланса
    // Сейчас мы просто считаем ключ валидным, если префикс совпал.
    bool isKeyValid = true; // Имитация успешной проверки
    // --- Конец ЗАГЛУШКИ ---

    if (isKeyValid) {
      final prefs = await SharedPreferences.getInstance();
      final random = Random();
      final pin = (1000 + random.nextInt(9000)).toString(); // Генерируем 4-значный PIN

      await prefs.setString(apiKeyKey, apiKey);
      await prefs.setString(pinKey, pin);
      await prefs.setString(activeProviderKey, determinedProvider);

      // Обновляем dotenv.
      dotenv.env['OPENROUTER_API_KEY'] = apiKey; 

      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false).apiSettingsUpdated();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ключ сохранен! Ваш PIN: $pin. Запомните его.'), duration: const Duration(seconds: 5)),
        );
        // Замените '/chat' на ваш реальный маршрут главного экрана
        Navigator.pushReplacementNamed(context, '/chat'); 
      }
    } else {
      _showError('API ключ невалиден или баланс отрицательный.'); // Сообщение для будущей реальной проверки
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка API Ключа'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Введите ваш API ключ',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ключ от OpenRouter должен начинаться с \'$openRouterPrefix\'.\nКлюч от VSEGPT должен начинаться с \'$vseGptPrefix\'.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Ключ',
                hintText: 'например, sk-or-v1-... или sk-or-vv-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveApiKeyAndProceed,
                    child: const Text('Проверить и сохранить ключ'),
                  ),
          ],
        ),
      ),
    );
  }
}