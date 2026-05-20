// lib/screens/search_messages_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../main.dart'; // chatService

class SearchMessagesScreen extends StatefulWidget {
  const SearchMessagesScreen({super.key});

  @override
  State<SearchMessagesScreen> createState() => _SearchMessagesScreenState();
}

class _SearchMessagesScreenState extends State<SearchMessagesScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Поиск сообщений'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Поиск по чатам...',
                prefixIcon: Icon(Icons.search,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF9CA3AF)),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? const Color(0xFF1A2332)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _results.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
              ),
              onSubmitted: (query) => _searchMessages(query),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'Введите текст для поиска',
                        style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade500,
                            fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final msg = _results[index];
                        return ListTile(
                          leading: Icon(Icons.chat_bubble_outline,
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF0a7ac2)
                                  : const Color(0xFF054582)),
                          title: Text(msg['text']!,
                              style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF1F2937))),
                          subtitle: Text('${msg['chat_name']} • ${msg['time']}',
                              style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                          onTap: () {
                            // Перейти к чату
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _searchMessages(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final searchResults = await chatService.searchMessagesInAllChats(query);

      setState(() {
        _results = searchResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка поиска: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
