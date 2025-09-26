import 'dart:math'; // Если понадобится для генерации PIN, но здесь скорее для валидации
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/chat_provider.dart';

// Ключи для SharedPreferences (можно вынести в отдельный файл констант)
const String apiKeyKey = 'api_key'; // Ключ активного провайдера
const String openRouterApiKeyPrefKey = 'openrouter_api_key'; // Ключ OpenRouter
const String vseGptApiKeyPrefKey = 'vsegpt_api_key';       // Ключ VSEGPT
const String pinKey = 'pin_code';
const String activeProviderKey = 'active_api_provider';

// Идентификаторы провайдеров
const String providerOpenRouter = 'OpenRouter';
const String providerVseGpt = 'VSEGPT';

// Префиксы ключей (если нужны для валидации здесь)
const String openRouterPrefix = 'sk-or-v1-';
const String vseGptPrefix = 'sk-or-vv-';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  // Контроллеры для API ключей
  final TextEditingController _openRouterApiKeyController = TextEditingController();
  final TextEditingController _vseGptApiKeyController = TextEditingController();
  
  // Контроллеры для PIN
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmNewPinController = TextEditingController();

  String _selectedProvider = providerOpenRouter; // Провайдер, выбранный в UI
  String? _currentOpenRouterApiKey;
  String? _currentVseGptApiKey;
  bool _pinExists = false;
  bool _isLoading = false;

  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    _prefs = await SharedPreferences.getInstance();

    _selectedProvider = _prefs.getString(activeProviderKey) ?? providerOpenRouter;
    _currentOpenRouterApiKey = _prefs.getString(openRouterApiKeyPrefKey);
    _currentVseGptApiKey = _prefs.getString(vseGptApiKeyPrefKey);
    _pinExists = _prefs.getString(pinKey) != null;

    _openRouterApiKeyController.text = _currentOpenRouterApiKey ?? '';
    _vseGptApiKeyController.text = _currentVseGptApiKey ?? '';

    setState(() {
      _isLoading = false;
    });
  }

  // Заглушка для отображения ошибок
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // Заглушка для отображения успеха
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  // TODO: Реализовать UI и логику для сохранения ключей и смены PIN
  // void _saveApiKeyForSelectedProvider() async { ... }
  // void _clearApiKeyForSelectedProvider() async { ... }
  // void _changePin() async { ... }

  @override
  void dispose() {
    _openRouterApiKeyController.dispose();
    _vseGptApiKeyController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmNewPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки Провайдера и PIN'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildProviderSelector(),
                  const SizedBox(height: 24),
                  _buildApiKeySection(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildPinChangeSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProviderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Выберите API Провайдера', style: Theme.of(context).textTheme.titleMedium),
        DropdownButtonFormField<String>(
          value: _selectedProvider,
          items: [providerOpenRouter, providerVseGpt].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedProvider = newValue;
              });
            }
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildApiKeySection() {
    // Отображаем поле ввода для текущего _selectedProvider
    final bool isOpenRouter = _selectedProvider == providerOpenRouter;
    final TextEditingController currentController = 
        isOpenRouter ? _openRouterApiKeyController : _vseGptApiKeyController;
    final String currentApiKey = isOpenRouter ? (_currentOpenRouterApiKey ?? '') : (_currentVseGptApiKey ?? '');
    final String hintText = isOpenRouter 
        ? 'API ключ для OpenRouter (начинается с $openRouterPrefix)' 
        : 'API ключ для VSEGPT (начинается с $vseGptPrefix)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('API Ключ для $_selectedProvider', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: currentController,
          decoration: InputDecoration(
            labelText: 'API Ключ',
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _saveApiKeyForSelectedProvider,
              child: const Text('Сохранить и Активировать'),
            ),
            TextButton(
              onPressed: _clearApiKeyForSelectedProvider,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Сбросить ключ'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinChangeSection() {
    if (!_pinExists) {
      return const Center(
        child: Text(
          'PIN-код еще не установлен. Он будет создан автоматически при первом сохранении API ключа через главный экран настроек.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Изменить PIN-код', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _currentPinController,
          decoration: const InputDecoration(
            labelText: 'Старый PIN-код',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPinController,
          decoration: const InputDecoration(
            labelText: 'Новый PIN-код (4 цифры)',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmNewPinController,
          decoration: const InputDecoration(
            labelText: 'Подтвердите новый PIN-код',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _changePin,
          child: const Text('Изменить PIN-код'),
        ),
      ],
    );
  }

  // --- Логика сохранения и изменения --- 

  Future<void> _saveApiKeyForSelectedProvider() async {
    setState(() { _isLoading = true; });
    final newApiKey = (_selectedProvider == providerOpenRouter 
        ? _openRouterApiKeyController.text 
        : _vseGptApiKeyController.text).trim();

    if (newApiKey.isEmpty) {
      _showError('API ключ не может быть пустым.');
      setState(() { _isLoading = false; });
      return;
    }

    // Валидация префикса
    if (_selectedProvider == providerOpenRouter && !newApiKey.startsWith(openRouterPrefix)) {
      _showError('Ключ OpenRouter должен начинаться с \'$openRouterPrefix\'');
      setState(() { _isLoading = false; });
      return;
    }
    if (_selectedProvider == providerVseGpt && !newApiKey.startsWith(vseGptPrefix)) {
      _showError('Ключ VSEGPT должен начинаться с \'$vseGptPrefix\'');
      setState(() { _isLoading = false; });
      return;
    }

    // Сохраняем ключ для конкретного провайдера
    if (_selectedProvider == providerOpenRouter) {
      await _prefs.setString(openRouterApiKeyPrefKey, newApiKey);
      _currentOpenRouterApiKey = newApiKey;
    } else {
      await _prefs.setString(vseGptApiKeyPrefKey, newApiKey);
      _currentVseGptApiKey = newApiKey;
    }

    // Устанавливаем его как активный ключ и провайдер
    await _prefs.setString(apiKeyKey, newApiKey); // Общий ключ для активного провайдера
    await _prefs.setString(activeProviderKey, _selectedProvider);
    dotenv.env['OPENROUTER_API_KEY'] = newApiKey; // Обновляем dotenv для немедленного использования

    // Если PIN еще не существует, создаем его
    if (!_pinExists) {
      final random = Random();
      final newPin = (1000 + random.nextInt(9000)).toString();
      await _prefs.setString(pinKey, newPin);
      _pinExists = true;
       _showSuccess('Ключ сохранен и активирован! Ваш новый PIN: $newPin. Запомните его.');
    } else {
      _showSuccess('Ключ для $_selectedProvider сохранен и активирован!');
    }

    if (mounted) {
      Provider.of<ChatProvider>(context, listen: false).apiSettingsUpdated();
    }
    
    setState(() {
      _isLoading = false;
       // Обновляем состояние контроллеров на всякий случай, если они изменятся
      _openRouterApiKeyController.text = _currentOpenRouterApiKey ?? '';
      _vseGptApiKeyController.text = _currentVseGptApiKey ?? '';
    });
  }

  Future<void> _clearApiKeyForSelectedProvider() async {
    setState(() { _isLoading = true; });
    final String currentActiveKeyInPrefs = _prefs.getString(apiKeyKey) ?? '';
    final String keyToClearForProvider; 
    final String keyControllerTextToClear;

    if (_selectedProvider == providerOpenRouter) {
      keyToClearForProvider = _currentOpenRouterApiKey ?? '';
      keyControllerTextToClear = _openRouterApiKeyController.text.trim();
      await _prefs.remove(openRouterApiKeyPrefKey);
      _currentOpenRouterApiKey = null;
      _openRouterApiKeyController.clear();
    } else {
      keyToClearForProvider = _currentVseGptApiKey ?? '';
      keyControllerTextToClear = _vseGptApiKeyController.text.trim();
      await _prefs.remove(vseGptApiKeyPrefKey);
      _currentVseGptApiKey = null;
      _vseGptApiKeyController.clear();
    }

    // Если удаляемый ключ был активным, также очищаем общий apiKeyKey и dotenv
    // и сообщаем ChatProvider
    if (currentActiveKeyInPrefs == keyToClearForProvider || currentActiveKeyInPrefs == keyControllerTextToClear) {
      await _prefs.remove(apiKeyKey);
      dotenv.env.remove('OPENROUTER_API_KEY');
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false).apiSettingsUpdated();
      }
      _showSuccess('Активный ключ для $_selectedProvider сброшен.');
    } else {
      _showSuccess('Ключ для $_selectedProvider сброшен (не был активным).');
    }

    setState(() { _isLoading = false; });
  }

  Future<void> _changePin() async {
    if (!_pinExists) {
      _showError('PIN-код еще не установлен.');
      return;
    }

    final currentPinInput = _currentPinController.text;
    final newPinInput = _newPinController.text;
    final confirmNewPinInput = _confirmNewPinController.text;

    final storedPin = _prefs.getString(pinKey);

    if (currentPinInput != storedPin) {
      _showError('Старый PIN-код введен неверно.');
      return;
    }
    if (newPinInput.isEmpty || newPinInput.length != 4 || int.tryParse(newPinInput) == null) {
      _showError('Новый PIN-код должен состоять из 4 цифр.');
      return;
    }
    if (newPinInput != confirmNewPinInput) {
      _showError('Новые PIN-коды не совпадают.');
      return;
    }
    if (newPinInput == storedPin) {
      _showError('Новый PIN-код не должен совпадать со старым.');
      return;
    }

    setState(() { _isLoading = true; });
    await _prefs.setString(pinKey, newPinInput);
    _currentPinController.clear();
    _newPinController.clear();
    _confirmNewPinController.clear();
    _showSuccess('PIN-код успешно изменен!');
    setState(() { _isLoading = false; });
  }
}
