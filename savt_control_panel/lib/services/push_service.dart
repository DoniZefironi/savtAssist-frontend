// Заглушка push-уведомлений.
// Для реального FCM: добавить firebase_messaging в pubspec.yaml
// и реализовать платформенную инициализацию Firebase.
class PushService {
  Future<void> registerToken() async {}
  Future<void> unregisterToken() async {}
}
