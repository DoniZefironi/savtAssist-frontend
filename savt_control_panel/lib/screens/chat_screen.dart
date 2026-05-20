import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/gradient_scaffold.dart';
import '../main.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  bool _hasMore = true;
  int? _oldestMessageId;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadMessages(); // Сначала загружаем сообщения
    _markAsRead(); // Потом отмечаем как прочитанные
  }

  Future<void> _loadMessages({bool loadOlder = false}) async {
    if (_isLoading && !loadOlder) return;
    if (loadOlder && !_hasMore) return;

    setState(() {
      if (!loadOlder) _isLoading = true;
      _error = '';
    });

    try {
      final dynamic raw = await chatService.getMessages(
        widget.chatId,
        beforeId: loadOlder ? _oldestMessageId : null,
        limit: 30,
      );

      final List<Map<String, dynamic>> newMessages = [];

      if (raw != null) {
        if (raw is List) {
          for (final dynamic item in raw) {
            if (item is Map) {
              newMessages.add(Map<String, dynamic>.from(item));
            }
          }
        } else if (raw is Map) {
          final dynamic items = raw['items'];
          if (items is List) {
            for (final dynamic item in items) {
              if (item is Map) {
                newMessages.add(Map<String, dynamic>.from(item));
              }
            }
          }
        }
      }

      setState(() {
        if (loadOlder) {
          _messages = [...newMessages, ..._messages];
        } else {
          _messages = newMessages;
        }
        if (newMessages.isNotEmpty) {
          _oldestMessageId = newMessages.last['id'] as int?;
          _hasMore = newMessages.length == 30;
        } else {
          _hasMore = false;
        }
        _isLoading = false;
      });

      if (!loadOlder && _messages.isNotEmpty) _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _markAsRead() async {
    try {
      await chatService.markAsRead(widget.chatId);
      debugPrint('Сообщения чата ${widget.chatId} отмечены как прочитанные');
    } catch (e) {
      debugPrint('Ошибка отметки прочитанным: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final newMsg = await chatService.sendTextMessage(widget.chatId, text);
      setState(() {
        _messages.add(newMsg);
        _messageController.clear();
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      _showError('Ошибка отправки: $e');
    }
  }

  Future<void> _pickImageAndSend() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) await _uploadAndSendFile(image, 'image');
  }

  Future<void> _pickFileAndSend() async {
    final picker = ImagePicker();
    final file = await picker.pickMedia();
    if (file != null) await _uploadAndSendFile(file, 'file');
  }

  Future<void> _pickAudioAndSend() async {
    final picker = ImagePicker();
    final audio = await picker.pickMedia();
    if (audio != null) {
      final ext = audio.name.split('.').last.toLowerCase();
      if (['m4a', 'mp3', 'wav', 'ogg', 'aac'].contains(ext)) {
        await _uploadAndSendFile(audio, 'voice');
      } else {
        _showError('Выберите аудиофайл (mp3, m4a, wav, ogg)');
      }
    }
  }

  Future<void> _uploadAndSendFile(XFile xFile, String type) async {
    setState(() => _isUploading = true);
    try {
      final url = type == 'voice'
          ? await uploadService.uploadVoice(xFile)
          : await uploadService.uploadAttachment(xFile);
      final fileName = xFile.name;
      final attachments = [
        {
          'url': url,
          'file_name': fileName,
          'file_type': type == 'voice' ? 'voice' : 'file'
        }
      ];
      final newMsg = await chatService.sendMessageWithAttachments(
          widget.chatId, null, attachments);
      setState(() {
        _messages.add(newMsg);
        _isUploading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isUploading = false);
      _showError('Ошибка загрузки файла: $e');
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(Icons.image, 'Фото', () {
                Navigator.pop(ctx);
                _pickImageAndSend();
              }),
              _buildOption(Icons.description, 'Файл', () {
                Navigator.pop(ctx);
                _pickFileAndSend();
              }),
              _buildOption(Icons.mic, 'Аудио', () {
                Navigator.pop(ctx);
                _pickAudioAndSend();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Чат',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadMessages, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) return _buildEmptyChat();
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels <= 0 && _hasMore && !_isLoading) {
          _loadMessages(loadOlder: true);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[_messages.length - 1 - index];
          return _buildMessageBubble(msg);
        },
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final theme = Theme.of(context);
    final isOwn = msg['is_own'] ?? false;
    final text = msg['text'] ?? '';
    final time = _formatTime(msg['created_at']);
    final attachments = msg['attachments'] as List? ?? [];
    final messageId = msg['id'];
    final reactions = msg['reactions'] as Map<String, dynamic>? ?? {};

    return Dismissible(
      key: Key('$messageId'),
      direction:
          isOwn ? DismissDirection.endToStart : DismissDirection.startToEnd,
      onDismissed: (_) => _deleteMessage(messageId),
      confirmDismiss: (direction) async => await _showDeleteConfirmDialog(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            gradient: isOwn
                ? const LinearGradient(
                    colors: [Color(0xFF054582), Color(0xFF0a7ac2)])
                : null,
            color: isOwn ? null : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isOwn ? 20 : 4),
              bottomRight: Radius.circular(isOwn ? 4 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (text.isNotEmpty)
                Text(text,
                    style: TextStyle(
                        color: isOwn
                            ? Colors.white
                            : theme.colorScheme.onSurface)),
              if (text.isNotEmpty && attachments.isNotEmpty)
                const SizedBox(height: 8),
              ...attachments
                  .map((attachment) => _buildAttachment(attachment, isOwn)),
              if (attachments.isNotEmpty && text.isEmpty)
                const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: TextStyle(
                          fontSize: 10,
                          color: isOwn
                              ? Colors.white70
                              : theme.colorScheme.onSurfaceVariant)),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all, size: 12, color: Colors.white70)
                  ],
                ],
              ),
              if (reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: reactions.entries.map((entry) {
                    final emoji = entry.key;
                    final count = entry.value is Map
                        ? (entry.value as Map)['count'] ?? 1
                        : entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOwn
                            ? Colors.white.withOpacity(0.2)
                            : theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$emoji $count',
                          style: TextStyle(
                              fontSize: 11,
                              color: isOwn
                                  ? Colors.white70
                                  : theme.colorScheme.onSurface)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMessageOptions(Map<String, dynamic> msg) async {
    final isOwn = msg['is_own'] ?? false;
    final text = msg['text'] ?? '';
    final messageId = msg['id'];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('Добавить реакцию'),
              onTap: () {
                Navigator.pop(ctx);
                _showReactionSelector(messageId);
              },
            ),
            if (isOwn && text.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(messageId, text);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title:
                    const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(messageId);
                },
              ),
            ] else if (!isOwn) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title:
                    const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(messageId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showReactionSelector(int messageId) async {
    final reactions = ['👍', '👎', '❤️', '😂', '😮', '😢', '🎉'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выберите реакцию',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reactions.map((emoji) {
                  return ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 24)),
                    selected: false,
                    onSelected: (selected) {
                      if (selected) {
                        Navigator.pop(ctx);
                        _addReaction(messageId, emoji);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addReaction(int messageId, String emoji) async {
    try {
      await chatService.addReaction(widget.chatId, messageId, emoji);
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == messageId);
        if (idx != -1) {
          final reactions =
              _messages[idx]['reactions'] as Map<String, dynamic>? ?? {};
          reactions[emoji] = (reactions[emoji] ?? 0) + 1;
          _messages[idx]['reactions'] = reactions;
        }
      });
    } catch (e) {
      _showError('Ошибка добавления реакции: $e');
    }
  }

  Future<void> _editMessage(int messageId, String currentText) async {
    final controller = TextEditingController(text: currentText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать сообщение'),
        content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Введите текст...')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != currentText) {
      try {
        await chatService.editMessage(widget.chatId, messageId, result);
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == messageId);
          if (idx != -1) {
            _messages[idx]['text'] = result;
            _messages[idx]['edited'] = true;
          }
        });
      } catch (e) {
        _showError('Ошибка редактирования: $e');
      }
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить сообщение'),
            content: const Text('Вы уверены? Это действие нельзя отменить.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Удалить',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await chatService.deleteMessage(widget.chatId, messageId);
      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
      });
    } catch (e) {
      _showError('Ошибка удаления: $e');
    }
  }

  Widget _buildAttachment(Map<String, dynamic> attachment, bool isOwn) {
    final theme = Theme.of(context);
    final fileType = attachment['file_type'] ?? 'file';
    final fileName = attachment['file_name'] ?? 'Файл';
    if (fileType == 'voice') {
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isOwn
              ? Colors.white.withOpacity(0.1)
              : theme.colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic,
                size: 16,
                color: isOwn ? Colors.white70 : theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(fileName,
                style: TextStyle(
                    fontSize: 12,
                    color:
                        isOwn ? Colors.white70 : theme.colorScheme.onSurface)),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isOwn
            ? Colors.white.withOpacity(0.1)
            : theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fileType == 'image' ? Icons.image : Icons.insert_drive_file,
                  size: 16,
                  color: isOwn ? Colors.white70 : theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(fileName,
                  style: TextStyle(
                      fontSize: 12,
                      color: isOwn
                          ? Colors.white70
                          : theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final date = DateTime.parse(isoTime);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildEmptyChat() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Нет сообщений', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadMessages(),
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file,
                color: theme.colorScheme.onSurfaceVariant),
            onPressed: _isUploading ? null : _showAttachmentOptions,
          ),
          IconButton(
            icon: Icon(Icons.mic, color: theme.colorScheme.primary),
            onPressed: _isUploading ? null : _pickAudioAndSend,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  hintStyle:
                      TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isUploading ? null : _sendMessage,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF054582), Color(0xFF0a7ac2)]),
                  shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _isSending || _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
