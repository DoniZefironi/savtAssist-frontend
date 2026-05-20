import 'package:flutter/material.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../main.dart';
import 'search_messages_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final int _currentIndex = 2;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final chats = await chatService.getChats();
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    return _chats.where((chat) {
      final name =
          (chat['cabinet_name'] ?? chat['chat_type']).toString().toLowerCase();
      final lastMsg =
          (chat['last_message_text'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          lastMsg.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadTotal = _chats.fold<int>(
        0, (sum, c) => sum + ((c['unread_count'] as num?)?.toInt() ?? 0));

    return GradientScaffold(
      appBarTitle: 'Чаты',
      appBarAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
                color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) _searchQuery = '';
              });
              if (_isSearchExpanded) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  FocusScope.of(context).requestFocus(_searchFocusNode);
                });
              } else {
                FocusScope.of(context).unfocus();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchMessagesScreen()),
              );
            },
            tooltip: 'Поиск по сообщениям',
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: _isSearchExpanded
                ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
                : EdgeInsets.zero,
            child: _isSearchExpanded
                ? _buildSearchField()
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Ошибка: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadChats,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                    : _filteredChats.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _filteredChats.length,
                            itemBuilder: (context, index) =>
                                _buildChatCard(_filteredChats[index], index),
                          ),
          ),
        ],
      ),
      bottomNavBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTapped,
        unreadCounts: {'chats': unreadTotal},
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Поиск по чатам...',
          hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
          prefixIcon: Icon(Icons.search,
              color: theme.colorScheme.onSurfaceVariant, size: 24),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat, int index) {
    final theme = Theme.of(context);
    final int unreadCount = (chat['unread_count'] as num?)?.toInt() ?? 0;
    final bool hasUnread = unreadCount > 0;
    final chatType = chat['chat_type'] as String;
    final name = chat['cabinet_name'] ?? _getChatTypeName(chatType);
    final lastMessage = chat['last_message_text'] ?? 'Нет сообщений';
    final lastTime = _formatTime(chat['last_message_at']);

    return AnimatedCard(
      index: index,
      onTap: () async {
        await Navigator.pushNamed(context, '/chat/${chat['id']}');
        _loadChats(); // Обновляем список чатов после возврата
      },
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: _getChatGradient(chatType),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _getChatGradient(chatType)[0].withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Icon(_getChatIcon(chatType), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: theme.colorScheme.onSurface),
                      ),
                    ),
                    Text(lastTime,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastMessage,
                  style: TextStyle(
                      fontSize: 13,
                      color: hasUnread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.normal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF054582), Color(0xFF0a7ac2)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF054582).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Text('$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  String _getChatTypeName(String type) {
    switch (type) {
      case 'cabinet':
        return 'Шкаф управления';
      case 'support':
        return 'Общие вопросы';
      case 'notes':
        return 'Заметки';
      default:
        return 'Чат';
    }
  }

  IconData _getChatIcon(String type) {
    switch (type) {
      case 'cabinet':
        return Icons.devices_other;
      case 'support':
        return Icons.support_agent;
      case 'notes':
        return Icons.note_alt;
      default:
        return Icons.chat;
    }
  }

  List<Color> _getChatGradient(String type) {
    switch (type) {
      case 'cabinet':
        return [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];
      case 'support':
        return [const Color(0xFF054582), const Color(0xFF0a7ac2)];
      case 'notes':
        return [const Color(0xFF059669), const Color(0xFF34D399)];
      default:
        return [const Color(0xFF054582), const Color(0xFF0a7ac2)];
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final date = DateTime.parse(isoTime);
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (date.month == now.month && now.day - date.day == 1) {
        return 'Вчера';
      } else {
        return '${date.day}.${date.month}';
      }
    } catch (_) {
      return '';
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Нет чатов',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/shu-list');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/knowledge');
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }
}
