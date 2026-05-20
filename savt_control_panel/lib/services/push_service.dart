import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';

class PushService {
  final ApiClient _apiClient;

  PushService(this._apiClient);

  Future<void> registerToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      // Определяем платформу (упрощённо – android)
      // В реальном приложении можно использовать dart:io Platform
      final platform = 'android'; // или 'ios' – определите по флагу

      await _apiClient.dio.post('/device-tokens', data: {
        'token': fcmToken,
        'platform': platform,
      });
    } catch (e) {
      // игнорируем
    }
  }

  Future<void> unregisterToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _apiClient.dio.delete('/device-tokens/$fcmToken');
      }
    } catch (e) {
      // игнорируем
    }
  }
}
