import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added

import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart'; // Initial API Key Setup
import 'screens/pin_screen.dart'; // Added
import 'screens/token_stats_screen.dart';
import 'screens/expenses_chart_screen.dart';

// Ключи для SharedPreferences (должны совпадать с теми, что в settings_screen.dart и pin_screen.dart)
const String apiKeyKey = 'api_key';
const String pinKey = 'pin_code';

// Именованные маршруты
const String chatRoute = '/chat';
const String pinRoute = '/pin';
const String settingsRoute = '/settings';

class ErrorBoundaryWidget extends StatelessWidget {
  final Widget child;
  const ErrorBoundaryWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundaryWidget: $error');
          debugPrint('Stack trace: $stackTrace');
          // В случае серьезной ошибки при инициализации, показываем экран ошибки
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.red,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Critical Error: $error',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

void main() async {
  String initialRoute = settingsRoute; // По умолчанию - экран настроек
  try {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };
    await dotenv.load(fileName: ".env");
    debugPrint('Environment loaded');

    // Проверяем наличие ключа и PIN для определения начального маршрута
    final prefs = await SharedPreferences.getInstance();
    final String? storedApiKey = prefs.getString(apiKeyKey);
    final String? storedPin = prefs.getString(pinKey);

    if (storedApiKey != null && storedApiKey.isNotEmpty && storedPin != null && storedPin.isNotEmpty) {
      initialRoute = pinRoute; // Если ключ и PIN есть, начинаем с экрана ввода PIN
    }

    debugPrint('Initial route: $initialRoute');
    runApp(ErrorBoundaryWidget(child: MyApp(initialRoute: initialRoute)));

  } catch (e, stackTrace) {
    debugPrint('Error starting app: $e');
    debugPrint('Stack trace: $stackTrace');
    // Можно показать экран ошибки, если что-то пошло не так даже до runApp
     runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error starting app: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(), // Ошибка создания ChatProvider будет поймана ErrorBoundaryWidget
      child: MaterialApp(
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: ScrollBehavior().copyWith(overscroll: false),
            child: child!,
          );
        },
        title: 'AI Chat',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru', 'RU'),
        supportedLocales: const [
          Locale('ru', 'RU'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
           colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF262626),
            foregroundColor: Colors.white,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF333333),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
            contentTextStyle: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontFamily: 'Roboto',
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Colors.white,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
              ),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF262626),
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
          ),
        ),
        initialRoute: initialRoute, // Устанавливаем начальный маршрут
        routes: {
          settingsRoute: (context) => const SettingsScreen(), // Экран начальной настройки API
          pinRoute: (context) => const PinScreen(),           // Экран ввода PIN
          chatRoute: (context) => const MainAppShell(),        // Главный экран приложения после аутентификации
        },
      ),
    );
  }
}

// Новый виджет оболочки для основного интерфейса приложения с BottomNavigationBar
class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0; // Индекс выбранной вкладки

  // Список виджетов для каждой вкладки
  // Убрали SettingsScreen отсюда, так как это теперь экран начальной настройки
  static const List<Widget> _widgetOptions = <Widget>[
    ChatScreen(),
    TokenStatsScreen(),
    ExpensesChartScreen(),
    // Если понадобится экран настроек ВНУТРИ приложения (не начальных), его можно добавить сюда
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.data_usage_outlined),
            label: 'Токены',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            label: 'Расходы',
          ),
          // Если понадобится вкладка настроек ВНУТРИ приложения, ее можно добавить сюда
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
