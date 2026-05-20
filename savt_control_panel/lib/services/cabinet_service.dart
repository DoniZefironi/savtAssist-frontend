import 'package:dio/dio.dart';
import 'api_client.dart';
import 'offline_service.dart';
import '../models/cabinet.dart';

class CabinetService {
  final ApiClient _apiClient;
  final OfflineService _offlineService;

  CabinetService(this._apiClient) : _offlineService = OfflineService();

  Future<List<Cabinet>> getUserCabinets() async {
    try {
      final response = await _apiClient.dio.get('/cabinets');
      final List<dynamic> data = response.data;
      final cabinets = data.map((json) => Cabinet.fromJson(json)).toList();
      await _offlineService.saveCache('cabinets_list', data);
      return cabinets;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('cabinets_list');
      if (cached != null) {
        final List<dynamic> data = cached is String ? <dynamic>[] : cached;
        return data.map((json) => Cabinet.fromJson(json)).toList();
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getCabinetDetail(int cabinetId) async {
    try {
      final response = await _apiClient.dio.get('/cabinets/$cabinetId');
      final detail = response.data;
      await _offlineService.saveCache('cabinet_detail_$cabinetId', detail);
      return detail;
    } on DioException catch (e) {
      final cached =
          await _offlineService.getCache('cabinet_detail_$cabinetId');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<void> updateCabinet(int cabinetId,
      {String? customName, String? customComment}) async {
    try {
      final Map<String, dynamic> data = {};
      if (customName != null) data['custom_name'] = customName;
      if (customComment != null) data['custom_comment'] = customComment;
      await _apiClient.dio.patch('/cabinets/$cabinetId', data: data);
      final cached =
          await _offlineService.getCache('cabinet_detail_$cabinetId');
      if (cached is Map<String, dynamic>) {
        if (customName != null) cached['custom_name'] = customName;
        if (customComment != null) cached['custom_comment'] = customComment;
        await _offlineService.saveCache('cabinet_detail_$cabinetId', cached);
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteCabinet(int cabinetId) async {
    try {
      await _apiClient.dio.delete('/cabinets/$cabinetId');
      await _offlineService.removeCache('cabinet_detail_$cabinetId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addCabinetByQr(String qrData) async {
    try {
      final response = await _apiClient.dio
          .post('/cabinets/add-by-qr', data: {'qr_data': qrData.trim()});
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'status': 'not_found', 'message': 'ШУ не найден'};
      } else if (e.response?.statusCode == 409) {
        return {
          'status': 'conflict',
          'message': 'Уже привязано или заявка есть'
        };
      }
      throw _handleError(e);
    }
  }

  Future<void> addCabinetByPhoto(String photoUrl, {String? userComment}) async {
    try {
      await _apiClient.dio.post('/cabinets/add-by-photo', data: {
        'photo_url': photoUrl,
        'user_comment': userComment,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getCabinetChat(int cabinetId) async {
    try {
      final response = await _apiClient.dio.get('/cabinets/$cabinetId/chat');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDocuments(int cabinetId,
      {int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '/cabinets/$cabinetId/documents',
        queryParameters: {'page': page, 'size': size},
      );
      final items =
          List<Map<String, dynamic>>.from(response.data['items'] ?? []);
      if (page == 1) {
        await _offlineService.saveCache('cabinet_documents_$cabinetId', items);
      }
      return items;
    } on DioException catch (e) {
      final cached =
          await _offlineService.getCache('cabinet_documents_$cabinetId');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      throw _handleError(e);
    }
  }

  Future<List<String>> getPhotos(int cabinetId,
      {int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '/cabinets/$cabinetId/photos',
        queryParameters: {'page': page, 'size': size},
      );
      final items = response.data['items'] as List? ?? [];
      final photos = items.map((item) => item['url'] as String).toList();
      if (page == 1) {
        await _offlineService.saveCache('cabinet_photos_$cabinetId', photos);
      }
      return photos;
    } on DioException catch (e) {
      final cached =
          await _offlineService.getCache('cabinet_photos_$cabinetId');
      if (cached != null) return List<String>.from(cached);
      throw _handleError(e);
    }
  }

  // ========== РАБОТА С ЗАЯВКАМИ НА ДОБАВЛЕНИЕ ШУ (МОДЕРАЦИЯ) ==========

  /// Получить список своих заявок на добавление ШУ (модерация)
  Future<List<Map<String, dynamic>>> getUserAdditionRequests() async {
    try {
      final response = await _apiClient.dio.get('/cabinet-addition-requests');
      return List<Map<String, dynamic>>.from(response.data['items'] ?? []);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Получить одну заявку по ID (для обновления статуса)
  Future<Map<String, dynamic>> getAdditionRequestStatus(int requestId) async {
    try {
      final response =
          await _apiClient.dio.get('/cabinet-addition-requests/$requestId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> requestDocumentAccess(int docId, {String? userMessage}) async {
    try {
      await _apiClient.dio.post('/documents/$docId/request-access', data: {
        'user_message': userMessage,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> getDocumentDownloadUrl(int docId) async {
    try {
      return '${ApiClient.baseUrl}/documents/$docId/download';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<int>> downloadDocumentWithAuth(int docId) async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/$docId/download',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data as List<int>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Ошибка загрузки данных';
  }
}
