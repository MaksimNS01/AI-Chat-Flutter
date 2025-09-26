// Импорт основных виджетов Flutter
import 'package:flutter/material.dart';
// Импорт для работы с системными сервисами (буфер обмена)
import 'package:flutter/services.dart';
// Импорт для работы с провайдерами состояния
import 'package:provider/provider.dart';
// Импорт для работы со шрифтами Google
import 'package:google_fonts/google_fonts.dart';
// Импорт провайдера чата
import '../providers/chat_provider.dart';
// Импорт модели сообщения
import '../models/message.dart';
// Импорт настроек
// import './settings_screen.dart'; // Если этот импорт больше не нужен напрямую
import './provider_settings_screen.dart'; // <<<--- Убедитесь, что этот импорт есть

// Виджет для обработки ошибок в UI
class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundary: $error');
          debugPrint('Stack trace: $stackTrace');
          return Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red,
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }
      },
    );
  }
}

// Виджет для отображения отдельного сообщения в чате
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final List<ChatMessage> messages;
  final int index;

  const _MessageBubble({
    required this.message,
    required this.messages,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: message.isUser
                  ? const Color(0xFF1A73E8)
                  : const Color(0xFF424242),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              message.cleanContent,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 13,
                locale: const Locale('ru', 'RU'),
              ),
            ),
          ),
          if (message.tokens != null || message.cost != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.tokens != null)
                    Text(
                      'Токенов: ${message.tokens}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  if (message.tokens != null && message.cost != null)
                    const SizedBox(width: 8),
                  if (message.cost != null)
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, child) {
                        final isVsetgpt =
                            chatProvider.baseUrl?.contains('vsetgpt.ru') ==
                                true;
                        return Text(
                          message.cost! < 0.001
                              ? isVsetgpt
                              ? 'Стоимость: <0.001₽'
                              : 'Стоимость: <\$0.001'
                              : isVsetgpt
                              ? 'Стоимость: ${message.cost!.toStringAsFixed(3)}₽'
                              : 'Стоимость: \$${message.cost!.toStringAsFixed(3)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    color: Colors.white54,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () {
                      final textToCopy = message.isUser
                          ? message.cleanContent
                          : (index > 0 ? '${messages[index - 1].cleanContent}\n\n${message.cleanContent}' : message.cleanContent);
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Текст скопирован',
                              style: TextStyle(fontSize: 12)),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: 'Копировать текст',
                  ),
                  if (!message.isUser) // Only add spacer for AI messages to keep copy button left
                    const Spacer() 
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Виджет для ввода сообщений
class _MessageInput extends StatefulWidget {
  final void Function(String) onSubmitted;

  const _MessageInput({required this.onSubmitted});

  @override
  _MessageInputState createState() => _MessageInputState();
}

// Состояние виджета ввода сообщений
class _MessageInputState extends State<_MessageInput> {
  final _controller = TextEditingController();
  bool _isComposing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    final String textToSubmit = text.trim();
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
    widget.onSubmitted(textToSubmit);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (String text) {
                setState(() {
                  _isComposing = text.trim().isNotEmpty;
                });
              },
              onSubmitted: _isComposing ? _handleSubmitted : null,
              decoration: const InputDecoration(
                hintText: 'Введите сообщение...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            color: _isComposing ? Colors.blue : Colors.grey,
            onPressed:
            _isComposing ? () => _handleSubmitted(_controller.text) : null,
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

// Основной экран чата (теперь StatefulWidget)
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottomButton = false;
  int _previousMessagesLength = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (chatProvider.messages.isNotEmpty) {
        _handleMessagesUpdated(); 
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      bool isScrolledUp = _scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - MediaQuery.of(context).size.height * 0.1;

      if (isScrolledUp && !_scrollController.position.atEdge && _scrollController.position.extentAfter < _scrollController.position.maxScrollExtent) {
        if (!_showScrollToBottomButton) {
          setState(() {
            _showScrollToBottomButton = true;
          });
        }
      } else {
        if (_showScrollToBottomButton) {
          setState(() {
            _showScrollToBottomButton = false;
          });
        }
      }
    }
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions && 
        _scrollController.position.maxScrollExtent > 0.0) { 
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions && 
        _scrollController.position.maxScrollExtent > 0.0) { 
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleMessagesUpdated() {
    if (mounted && _scrollController.hasClients) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && 
              _scrollController.position.hasContentDimensions && 
              _scrollController.position.maxScrollExtent > 0.0) { 
            _scrollToBottom();
          }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildMessagesList(context),
                    if (_showScrollToBottomButton)
                      Positioned(
                        bottom: 16.0,
                        right: 16.0,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          backgroundColor: Colors.blueAccent.withOpacity(0.8),
                          child: const Icon(Icons.arrow_downward, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              _buildInputArea(context),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF262626),
      toolbarHeight: 48,
      title: Row(
        children: [
          _buildModelSelector(context),
          const Spacer(),
          _buildBalanceDisplay(context),
          _buildMenuButton(context),
        ],
      ),
    );
  }

  Widget _buildModelSelector(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: DropdownButton<String>(
            value: chatProvider.currentModel,
            hint: const Text(
              'Выберите модель',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            dropdownColor: const Color(0xFF333333),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            isExpanded: true,
            underline: Container(
              height: 1,
              color: Colors.blue,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                chatProvider.setCurrentModel(newValue);
              }
            },
            items: chatProvider.availableModels
                .map<DropdownMenuItem<String>>((Map<String, dynamic> model) {
              return DropdownMenuItem<String>(
                value: model['id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      model['name'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if(model['pricing'] != null && model['pricing']['prompt'] != null && model['pricing']['completion'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          children: [
                            Tooltip(
                              message: 'Входные токены',
                              child: const Icon(Icons.arrow_upward, size: 10, color: Colors.white54),
                            ),
                            Text(
                              chatProvider.formatPricing(
                                  double.tryParse(model['pricing']!['prompt'].toString()) ?? 0.0),
                              style: const TextStyle(fontSize: 9, color: Colors.white54),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Генерация',
                              child: const Icon(Icons.arrow_downward, size: 10, color: Colors.white54),
                            ),
                            Text(
                              chatProvider.formatPricing(double.tryParse(
                                  model['pricing']!['completion'].toString()) ?? 0.0),
                              style: const TextStyle(fontSize: 9, color: Colors.white54),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Контекст',
                              child: const Icon(Icons.memory, size: 10, color: Colors.white54),
                            ),
                            Text(
                              ' ${model['context_length'] ?? '0'}',
                              style: const TextStyle(fontSize: 9, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBalanceDisplay(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: Row(
            children: [
              const Icon(Icons.credit_card, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                chatProvider.balance,
                style: const TextStyle(
                  color: Color(0xFF33CC33),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 16),
      color: const Color(0xFF333333),
      onSelected: (String choice) async {
        // final chatProvider = context.read<ChatProvider>(); // chatProvider не используется здесь напрямую, но может понадобиться
        switch (choice) {
          case 'export':
            final path = await context.read<ChatProvider>().exportMessagesAsJson(); // Используем context.read
            if (mounted) { // mounted используется здесь, поэтому context нужен
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('История сохранена в: $path',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green,
                ),
              );
            }
            break;
          case 'logs':
            final path = await context.read<ChatProvider>().exportLogs(); // Используем context.read
            if (mounted) { // mounted используется здесь, поэтому context нужен
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Логи сохранены в: $path',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green,
                ),
              );
            }
            break;
          case 'clear':
            _showClearHistoryDialog(context);
            break;
          case 'provider_settings': // <<<--- НОВЫЙ CASE
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProviderSettingsScreen()),
            );
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'export',
          height: 40,
          child: Text('Экспорт истории',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'logs',
          height: 40,
          child: Text('Скачать логи',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'clear',
          height: 40,
          child: Text('Очистить историю',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const PopupMenuItem<String>( // <<<--- НОВЫЙ ПУНКТ МЕНЮ
          value: 'provider_settings',
          height: 40, // или какая у вас стандартная высота
          child: Text('Настройки API и PIN', style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildMessagesList(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (_previousMessagesLength != chatProvider.messages.length) {
            _handleMessagesUpdated(); // Вызываем единый обработчик
          _previousMessagesLength = chatProvider.messages.length;
        }

        if (chatProvider.messages.isEmpty) {
          return const Center(
            child: Text(
              'Нет сообщений. Начните диалог!',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            final message = chatProvider.messages[index];
            return _MessageBubble(
              message: message,
              messages: chatProvider.messages,
              index: index,
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF262626),
      child: _MessageInput(
        onSubmitted: (String text) {
          context.read<ChatProvider>().sendMessage(text);
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF262626),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context: context,
            icon: Icons.save,
            label: 'Сохранить',
            color: const Color(0xFF1A73E8),
            onPressed: () async {
              final path =
              await context.read<ChatProvider>().exportMessagesAsJson();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('История сохранена в: $path',
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          _buildActionButton(
            context: context,
            icon: Icons.analytics,
            label: 'Аналитика',
            color: const Color(0xFF33CC33),
            onPressed: () => _showAnalyticsDialog(context),
          ),
          _buildActionButton(
            context: context,
            icon: Icons.delete,
            label: 'Очистить',
            color: const Color(0xFFCC3333),
            onPressed: () => _showClearHistoryDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
        ),
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context) {
    final chatProvider = context.read<ChatProvider>(); // Используем локальную переменную, а не context.read если не меняем состояние
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Переименовываем context во избежание конфликта
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Статистика',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Всего сообщений: ${chatProvider.messages.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Баланс: ${chatProvider.balance}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Использование по моделям:',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                const SizedBox(height: 8),
                // Для отображения статистики из AnalyticsService, используем FutureBuilder
                FutureBuilder<Map<String, Map<String, int>>>(
                  future: chatProvider.modelTokenUsageStats, // Получаем Future
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snapshot.hasError) {
                      return Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('Нет данных по моделям.', style: TextStyle(color: Colors.white70, fontSize: 12));
                    }
                    final modelUsage = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: modelUsage.entries.map((entry) {
                        final modelId = entry.key;
                        final stats = entry.value;
                        final count = stats['count'] ?? 0;
                        final tokens = stats['tokens'] ?? 0;
                        // Стоимость здесь не трекается отдельно в modelTokenUsageStats, она в общем балансе
                        return Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                modelId,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Сообщений: $count',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              if (tokens > 0) ...[
                                Text(
                                  'Токенов: $tokens',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // Используем dialogContext
              child: const Text('Закрыть', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Переименовываем context
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Очистить историю',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: const Text(
            'Вы уверены? Это действие нельзя отменить.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // Используем dialogContext
              child: const Text('Отмена', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () {
                context.read<ChatProvider>().clearHistory();
                Navigator.of(dialogContext).pop(); // Используем dialogContext
              },
              child: const Text(
                'Очистить',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}
