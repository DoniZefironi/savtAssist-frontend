// lib/services/notification_service.dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class Notification {
  final int id;
  final String title;
  final String message;
  final String? type;
  final String? data;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'],
      data: json['data'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  /// Получить список уведомлений
  Future<Map<String, dynamic>> getNotifications({
    bool? isRead,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (isRead != null) query['is_read'] = isRead;
      
      final response = await _apiClient.dio.get(
        '/notifications',
        queryParameters: query,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Отметить уведомление как прочитанное
  Future<void> markAsRead(int notificationId) async {
    try {
      await _apiClient.dio.post('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Отметить все уведомления как прочитанные
  Future<void> markAllAsRead() async {
    try {
      await _apiClient.dio.post('/notifications/read-all');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Получить настройки уведомлений
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _apiClient.dio.get('/notifications/settings');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Обновить настройки уведомлений
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _apiClient.dio.patch('/notifications/settings', data: settings);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Ошибка работы с уведомлениями';
  }
}
