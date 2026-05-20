import 'package:dio/dio.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthService(this._apiClient, this._tokenStorage);

  Future<void> registerStart({
    required String phone,
    required String password,
    required String fullName,
    required String userType,
    String? organizationName,
  }) async {
    try {
      await _apiClient.dio.post('/auth/register/start', data: {
        'phone': phone,
        'password': password,
        'password_confirm': password,
        'full_name': fullName,
        'user_type': userType,
        'organization_name': organizationName,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> registerComplete(String phone, String code) async {
    try {
      final response =
          await _apiClient.dio.post('/auth/register/complete', data: {
        'phone': phone,
        'code': code,
      });
      final data = response.data;
      await _tokenStorage.saveTokens(
          data['access_token'], data['refresh_token']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> login(String phone, String password) async {
    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      final data = response.data;
      await _tokenStorage.saveTokens(
          data['access_token'], data['refresh_token']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    final refresh = await _tokenStorage.getRefreshToken();
    if (refresh != null) {
      await _apiClient.dio
          .post('/auth/logout', data: {'refresh_token': refresh});
    }
    await _tokenStorage.clearTokens();
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> passwordResetStart(String phone) async {
    try {
      await _apiClient.dio
          .post('/auth/password-reset/start', data: {'phone': phone});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> passwordResetComplete(
      String phone, String code, String newPassword) async {
    try {
      await _apiClient.dio.post('/auth/password-reset/complete', data: {
        'phone': phone,
        'code': code,
        'new_password': newPassword,
        'new_password_confirm': newPassword,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      await _apiClient.dio.post('/auth/password-change', data: {
        'password': oldPassword,
        'new_password': newPassword,
        'new_password_confirm': newPassword,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> resendRegisterCode(String phone) async {
    try {
      await _apiClient.dio
          .post('/auth/register/resend', data: {'phone': phone});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changePhoneStart(String newPhone) async {
    try {
      await _apiClient.dio
          .post('/auth/change-phone/start', data: {'new_phone': newPhone});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changePhoneComplete(String newPhone, String code) async {
    try {
      await _apiClient.dio.post('/auth/change-phone/complete', data: {
        'new_phone': newPhone,
        'code': code,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Нет соединения с сервером';
    }
    return 'Произошла ошибка. Попробуйте позже.';
  }
}
