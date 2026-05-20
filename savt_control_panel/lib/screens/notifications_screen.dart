// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/notification_service.dart' as notif;
import '../services/offline_service.dart';
import '../main.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final notif.NotificationService _notificationService =
      notif.NotificationService(apiClient);
  List<notif.Notification> _notifications = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    setState(() {
      if (!refresh) _isLoading = true;
      _error = '';
    });

    try {
      final response = await _notificationService.getNotifications(
          isRead: false, page: 1, size: 50);
      final items = response['items'] as List? ?? [];
      final notifications =
          items.map((json) => notif.Notification.fromJson(json)).toList();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      final unreadCount = _notifications.where((n) => !n.isRead).length;
      OfflineService().updateUnreadNotificationCount(unreadCount);
    } on DioException catch (e) {
      setState(() {
        _error = _getErrorDetail(e);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(notif.Notification notification) async {
    try {
      await _notificationService.markAsRead(notification.id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notif.Notification(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            data: notification.data,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }
      });
      final unreadCount = _notifications.where((n) => !n.isRead).length;
      OfflineService().updateUnreadNotificationCount(unreadCount);
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      setState(() {
        _notifications = _notifications
            .map((n) => notif.Notification(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  type: n.type,
                  data: n.data,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
      });
      OfflineService().updateUnreadNotificationCount(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Все уведомления прочитаны'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  String _getErrorDetail(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Ошибка загрузки уведомлений';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${createdAt.day}.${createdAt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Уведомления'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _isLoading ? null : _markAllAsRead,
              child: const Text('Прочитать всё',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text('Ошибка: $_error'))
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Нет уведомлений',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(notif.Notification notification) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Card(
      color: isUnread
          ? theme.colorScheme.primary.withOpacity(0.05)
          : theme.colorScheme.surface,
      elevation: isUnread ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isUnread
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isUnread
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getIconForType(notification.type),
              color: isUnread ? Colors.white : theme.colorScheme.primary,
              size: 20),
        ),
        title: Text(notification.title,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(_formatTime(notification.createdAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline, fontSize: 11)),
          ],
        ),
        trailing: isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary, shape: BoxShape.circle))
            : null,
        onTap: () => _markAsRead(notification),
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'warranty_expiring':
        return Icons.warning_amber;
      case 'chat_message':
        return Icons.chat_bubble;
      case 'request_status':
        return Icons.support_agent;
      case 'promotional':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }
}
