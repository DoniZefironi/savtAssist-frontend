import 'package:dio/dio.dart';
import 'api_client.dart';

class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  Future<List<Map<String, dynamic>>> getChats() async {
    try {
      final response = await _apiClient.dio.get(
        '/chats',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getCabinetChat(int cabinetId) async {
    try {
      final response = await _apiClient.dio.get(
        '/cabinets/$cabinetId/chat',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>?> getMessages(
    int chatId, {
    int? beforeId,
    int limit = 30,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (beforeId != null) query['before_id'] = beforeId;

      final response = await _apiClient.dio.get(
        '/chats/$chatId/messages',
        queryParameters: query,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 204) return null;
      if (response.data == null) return null;

      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw 'Таймаут соединения. Проверьте подключение к серверу.';
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendTextMessage(int chatId, String text) async {
    try {
      final response = await _apiClient.dio.post(
        '/chats/$chatId/messages',
        data: {'text': text},
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendMessageWithAttachments(
    int chatId,
    String? text,
    List<Map<String, dynamic>> attachments,
  ) async {
    try {
      final data = <String, dynamic>{};
      if (text != null && text.isNotEmpty) data['text'] = text;
      if (attachments.isNotEmpty) data['attachments'] = attachments;

      final response = await _apiClient.dio.post(
        '/chats/$chatId/messages',
        data: data,
        options: Options(
          receiveTimeout:
              const Duration(seconds: 30), // Больше времени для загрузки файлов
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAsRead(int chatId) async {
    try {
      await _apiClient.dio.post(
        '/chats/$chatId/read',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> addReaction(int chatId, int messageId, String emoji) async {
    try {
      await _apiClient.dio.post(
        '/chats/$chatId/messages/$messageId/reactions/$emoji',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> removeReaction(int chatId, int messageId, String emoji) async {
    try {
      await _apiClient.dio.delete(
        '/chats/$chatId/messages/$messageId/reactions/$emoji',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> editMessage(int chatId, int messageId, String newText) async {
    try {
      await _apiClient.dio.patch(
        '/chats/$chatId/messages/$messageId',
        data: {'text': newText},
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    try {
      await _apiClient.dio.delete(
        '/chats/$chatId/messages/$messageId',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> searchMessagesInAllChats(
    String query,
  ) async {
    try {
      final allChats = await getChats();
      final results = <Map<String, dynamic>>[];
      final lowerQuery = query.toLowerCase();

      for (final chat in allChats) {
        final chatId = chat['id'] as int;
        final chatName =
            chat['cabinet_name'] ?? _getChatTypeName(chat['chat_type'] ?? '');

        try {
          final messages = await getMessages(chatId, limit: 50);
          if (messages == null) continue;

          for (final msg in messages) {
            final text = msg['text'] as String? ?? '';
            if (text.toLowerCase().contains(lowerQuery)) {
              results.add({
                'id': msg['id'],
                'chat_id': chatId,
                'chat_name': chatName,
                'text': text,
                'created_at': msg['created_at'],
                'time': _formatTime(msg['created_at']),
                'is_own': msg['is_own'] ?? false,
              });
            }
          }
        } catch (_) {
          continue;
        }
      }

      results.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '');
        final dateB = DateTime.tryParse(b['created_at'] ?? '');
        if (dateA != null && dateB != null) return dateB.compareTo(dateA);
        return 0;
      });

      return results;
    } catch (e) {
      if (e is DioException) throw _handleError(e);
      throw 'Ошибка поиска сообщений: $e';
    }
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

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final date = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Только что';
      if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
      if (diff.inDays < 1) return '${diff.inHours} ч. назад';
      if (diff.inDays < 7) return '${diff.inDays} дн. назад';
      return '${date.day}.${date.month}';
    } catch (_) {
      return '';
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Таймаут соединения. Проверьте подключение к серверу.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Ошибка подключения. Проверьте интернет-соединение.';
    }
    return 'Ошибка загрузки данных чата';
  }
}
