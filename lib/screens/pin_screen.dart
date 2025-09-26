import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter

// Ключи для SharedPreferences (должны совпадать с теми, что в settings_screen.dart)
const String apiKeyKey = 'api_key';
const String pinKey = 'pin_code';
const String activeProviderKey = 'active_api_provider';

// Именованные маршруты (предполагаем, что они определены в main.dart)
const String settingsRoute = '/settings'; // Маршрут к экрану настроек
const String chatRoute = '/chat'; // Маршрут к главному экрану чата

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _checkPin() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final enteredPin = _pinController.text;
    if (enteredPin.length != 4) {
      _showError('PIN должен состоять из 4 цифр.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(pinKey);

    if (savedPin == enteredPin) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, chatRoute);
      }
    } else {
      _showError('Неверный PIN-код.');
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _resetKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(apiKeyKey);
    await prefs.remove(pinKey);
    await prefs.remove(activeProviderKey);
    // Также, если вы сохраняли ключ в dotenv и хотите его очистить при сбросе:
    // await dotenv.load(); // Перезагрузить .env
    // dotenv.env.remove('OPENROUTER_API_KEY'); // или установить в null/пустую строку

    if (mounted) {
      Navigator.pushReplacementNamed(context, settingsRoute);
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
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Введите PIN-код'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Введите ваш 4-значный PIN-код',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN-код',
                border: OutlineInputBorder(),
                counterText: "", // Скрыть счетчик символов
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _checkPin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    child: const Text('Войти', style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _resetKey,
              child: const Text('Сбросить ключ / Забыли PIN?'),
            ),
          ],
        ),
      ),
    );
  }
}
