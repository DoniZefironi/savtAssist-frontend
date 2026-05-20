import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService(this._apiClient);

  Future<String> uploadAttachment(XFile xFile) async {
    try {
      final bytes = await xFile.readAsBytes();
      final file = MultipartFile.fromBytes(bytes, filename: xFile.name);
      final formData = FormData.fromMap({'file': file});
      final response = await _apiClient.dio.post(
        '/upload/attachment',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return response.data['url'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadVoice(XFile xFile) async {
    try {
      final bytes = await xFile.readAsBytes();
      final file = MultipartFile.fromBytes(bytes, filename: xFile.name);
      final formData = FormData.fromMap({'file': file});
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
