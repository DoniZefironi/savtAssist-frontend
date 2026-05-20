// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../main.dart'; // apiClient

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _newMessages = true;
  bool _warranty30 = true;
  bool _warranty10 = true;
  bool _warranty1 = true;
  bool _promo = false;
  bool _requestStatus = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await apiClient.dio.get('/notifications/settings');
      final data = response.data;
      setState(() {
        _newMessages = data['new_messages'] ?? true;
        _warranty30 = data['warranty_30_days'] ?? true;
        _warranty10 = data['warranty_10_days'] ?? true;
        _warranty1 = data['warranty_1_day'] ?? true;
        _promo = data['promo'] ?? false;
        _requestStatus = data['request_status'] ?? true;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      _showError(_getErrorDetail(e));
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка загрузки: $e');
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    try {
      await apiClient.dio.patch('/notifications/settings', data: {key: value});
    } on DioException catch (e) {
      _showError(_getErrorDetail(e));
    }
  }

  String _getErrorDetail(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Ошибка сохранения настроек';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Настройки уведомлений'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки уведомлений'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Сообщения'),
          _buildSwitch('Новые сообщения в чатах', _newMessages, (val) {
            setState(() => _newMessages = val);
            _updateSetting('new_messages', val);
          }),
          const Divider(),
          _buildSection('Гарантия'),
          _buildSwitch('За 30 дней до окончания', _warranty30, (val) {
            setState(() => _warranty30 = val);
            _updateSetting('warranty_30_days', val);
          }),
          _buildSwitch('За 10 дней до окончания', _warranty10, (val) {
            setState(() => _warranty10 = val);
            _updateSetting('warranty_10_days', val);
          }),
          _buildSwitch('За 1 день до окончания', _warranty1, (val) {
            setState(() => _warranty1 = val);
            _updateSetting('warranty_1_day', val);
          }),
          const Divider(),
          _buildSection('Другое'),
          _buildSwitch('Рекламные уведомления', _promo, (val) {
            setState(() => _promo = val);
            _updateSetting('promo', val);
          }),
          _buildSwitch('Изменение статуса запросов', _requestStatus, (val) {
            setState(() => _requestStatus = val);
            _updateSetting('request_status', val);
          }),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(title,
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildSwitch(String title, bool value, Function(bool) onChanged) {
    final theme = Theme.of(context);
    return SwitchListTile(
      title: Text(title,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
    );
  }
}
