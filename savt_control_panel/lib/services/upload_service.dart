import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService(this._apiClient);

  /// Загрузить файл (изображение, документ, видео)
  Future<String> uploadAttachment(String filePath) async {
    try {
      final fileName = filePath.split('/').last;
      final file = await MultipartFile.fromFile(filePath, filename: fileName);
      final formData = FormData.fromMap({
        'file': file,
      });
      final response = await _apiClient.dio.post(
        '/upload/attachment',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      // Ожидаемый ответ { "url": "/static/photos/abc.jpg" }
      return response.data['url'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Загрузить голосовое сообщение
  Future<String> uploadVoice(String filePath) async {
    try {
      final fileName = filePath.split('/').last;
      final file = await MultipartFile.fromFile(filePath, filename: fileName);
      final formData = FormData.fromMap({
        'file': file,
      });
      final response = await _apiClient.dio.post(
        '/upload/voice',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return response.data['url'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Ошибка загрузки файла';
  }
}
