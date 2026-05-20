// lib/services/offline_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final List<Map<String, dynamic>> _messageQueue = [];
  final List<Map<String, dynamic>> _downloadQueue = [];
  bool _isOnline = true;
  Timer? _connectionTimer;

  // Кэш для ранее загруженных данных
  static final Map<String, dynamic> _cache = {};

  // Счетчик непрочитанных уведомлений
  static final ValueNotifier<int> unreadNotificationCount = ValueNotifier(0);

  void start() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final newStatus = Random().nextDouble() > 0.1;
      if (newStatus != _isOnline) {
        _isOnline = newStatus;
        if (_isOnline) {
          _processQueues();
        }
      }
    });
    // Загружаем очередь сообщений при старте
    _loadMessageQueue();
  }

  void stop() {
    _connectionTimer?.cancel();
  }

  bool get isOnline => _isOnline;

  void addToQueue(String chatId, String text, String time) {
    _messageQueue.add({
      'chatId': chatId,
      'text': text,
      'time': time,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _saveMessageQueue();
  }

  void addDownloadToQueue(String docId, String docName, String shuId) {
    _downloadQueue.add({
      'docId': docId,
      'docName': docName,
      'shuId': shuId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> get pendingMessages =>
      List.unmodifiable(_messageQueue);

  List<Map<String, dynamic>> get pendingDownloads =>
      List.unmodifiable(_downloadQueue);

  void _processQueues() {
    if (_messageQueue.isEmpty && _downloadQueue.isEmpty) return;

    // Обработка очереди сообщений
    _messageQueue.clear();
    _saveMessageQueue();

    // Обработка очереди загрузок
    _downloadQueue.clear();

    print('Очереди обработаны');
  }

  // Кэширование данных с использованием SharedPreferences
  Future<void> saveCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String jsonString;

      if (data is String) {
        jsonString = data;
      } else {
        jsonString = jsonEncode(data);
      }

      await prefs.setString(key, jsonString);
      _cache[key] = data;
    } catch (e) {
      print('Ошибка сохранения кэша: $e');
    }
  }

  Future<dynamic> getCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        return _cache[key];
      }

      // Пытаемся распарсить JSON
      try {
        final parsed = jsonDecode(jsonString);
        _cache[key] = parsed;
        return parsed;
      } catch (_) {
        // Если не JSON, возвращаем как строку
        _cache[key] = jsonString;
        return jsonString;
      }
    } catch (e) {
      print('Ошибка чтения кэша: $e');
      return _cache[key];
    }
  }

  bool hasCachedData(String key) {
    return _cache.containsKey(key) || _cache.containsKey(key);
  }

  // Сохранение очереди сообщений в локальное хранилище
  Future<void> _saveMessageQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueString = jsonEncode(_messageQueue);
      await prefs.setString('message_queue', queueString);
    } catch (e) {
      print('Ошибка сохранения очереди: $e');
    }
  }

  // Загрузка очереди сообщений из локального хранилища
  Future<void> _loadMessageQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueString = prefs.getString('message_queue');

      if (queueString != null) {
        final List<dynamic> parsed = jsonDecode(queueString);
        _messageQueue.clear();
        _messageQueue.addAll(parsed.map((e) => e as Map<String, dynamic>));
      }
    } catch (e) {
      print('Ошибка загрузки очереди: $e');
    }
  }

  // Обновление счетчика непрочитанных уведомлений
  void updateUnreadNotificationCount(int count) {
    unreadNotificationCount.value = count;
  }

  // Очистка кэша
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _cache.clear();
    } catch (e) {
      print('Ошибка очистки кэша: $e');
    }
  }

  // Удаление конкретного ключа из кэша
  Future<void> removeCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      _cache.remove(key);
    } catch (e) {
      print('Ошибка удаления кэша: $e');
    }
  }
}
