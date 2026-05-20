import 'dart:async';
import 'package:dio/dio.dart';
import 'token_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://10.1.0.208:8000';

  final Dio _dio;
  final TokenStorage _tokenStorage;
  bool _isRefreshing = false;
  final List<
      ({
        void Function(String token) resolve,
        void Function(DioException error) reject,
      })> _queue = [];

  ApiClient(this._tokenStorage)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Обработка ошибок CORS и сетевых ошибок для веба
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.receiveTimeout) {
          print('CORS/Network error: ${error.message}');
        }

        if (error.response?.statusCode == 405) {
          print('Method Not Allowed - проверьте CORS настройки сервера');
        }

        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshToken = await _tokenStorage.getRefreshToken();
            if (refreshToken == null) throw Exception('No refresh token');
            final response = await _dio
                .post('/auth/refresh', data: {'refresh_token': refreshToken});
            final newAccess = response.data['access_token'];
            final newRefresh = response.data['refresh_token'];
            await _tokenStorage.saveTokens(newAccess, newRefresh);

            _isRefreshing = false;
            for (final entry in _queue) {
              entry.resolve(newAccess);
            }
            _queue.clear();

            final newOptions = error.requestOptions;
            newOptions.headers['Authorization'] = 'Bearer $newAccess';
            final retryResponse = await _dio.fetch(newOptions);
            return handler.resolve(retryResponse);
          } catch (e) {
            _isRefreshing = false;
            for (final entry in _queue) {
              entry.reject(error);
            }
            _queue.clear();
            await _tokenStorage.clearTokens();
            return handler.next(error);
          }
        } else if (error.response?.statusCode == 401 && _isRefreshing) {
          final completer = Completer<String>();
          _queue.add((
            resolve: (token) => completer.complete(token),
            reject: (err) => completer.completeError(err)
          ));
          try {
            final newToken = await completer.future;
            final newOptions = error.requestOptions;
            newOptions.headers['Authorization'] = 'Bearer $newToken';
            final retryResponse = await _dio.fetch(newOptions);
            return handler.resolve(retryResponse);
          } catch (e) {
            return handler.next(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
}
