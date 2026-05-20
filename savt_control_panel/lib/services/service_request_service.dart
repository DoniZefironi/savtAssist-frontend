// lib/services/service_request_service.dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class ServiceRequestService {
  final ApiClient _apiClient;

  ServiceRequestService(this._apiClient);

  /// Создать новую заявку на обслуживание
  Future<Map<String, dynamic>> createServiceRequest({
    required int cabinetId,
    required String
        requestType, // "repair", "maintenance", "inspection", "other"
    required String description,
  }) async {
    try {
      final response = await _apiClient.dio.post('/service-requests', data: {
        'cabinet_id': cabinetId,
        'request_type': requestType,
        'description': description,
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Получить список заявок текущего пользователя
  Future<Map<String, dynamic>> getServiceRequests({
    String? status, // 'open', 'in_progress', 'closed'
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (status != null) query['status'] = status;
      final response =
          await _apiClient.dio.get('/service-requests', queryParameters: query);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Ошибка при работе с заявками';
  }
}
