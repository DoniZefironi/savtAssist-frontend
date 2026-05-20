import 'package:dio/dio.dart';
import 'api_client.dart';
import 'offline_service.dart';
import '../utils/file_download.dart';

class KnowledgeService {
  final ApiClient _apiClient;
  final OfflineService _offlineService;

  KnowledgeService(this._apiClient) : _offlineService = OfflineService();

  Future<List<Map<String, dynamic>>> getKbCategories() async {
    try {
      final response = await _apiClient.dio.get('/kb/categories');
      final data = List<Map<String, dynamic>>.from(response.data);
      await _offlineService.saveCache('kb_categories', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('kb_categories');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getKbArticles({
    int? categoryId,
    List<int>? tagIds,
    String? search,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (categoryId != null) query['category_id'] = categoryId;
      if (tagIds != null && tagIds.isNotEmpty) query['tag_ids'] = tagIds;
      if (search != null && search.isNotEmpty) query['search'] = search;
      final response =
          await _apiClient.dio.get('/kb/articles', queryParameters: query);
      final data = response.data;
      if (page == 1 &&
          categoryId == null &&
          (tagIds == null || tagIds.isEmpty) &&
          search == null) {
        await _offlineService.saveCache('kb_articles', data);
      }
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('kb_articles');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getKbArticleDetail(int articleId) async {
    try {
      final response = await _apiClient.dio.get('/kb/articles/$articleId');
      final data = response.data;
      await _offlineService.saveCache('kb_article_$articleId', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('kb_article_$articleId');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<void> downloadKbAttachment(int articleId, int attachmentId) async {
    try {
      final response = await _apiClient.dio.get(
        '/kb/articles/$articleId/attachments/$attachmentId/download',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data as List<int>;
      await saveAndOpenFile(bytes, 'kb_attachment_$attachmentId.pdf');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getFaqCategories() async {
    try {
      final response = await _apiClient.dio.get('/faq/categories');
      final data = List<Map<String, dynamic>>.from(response.data);
      await _offlineService.saveCache('faq_categories', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('faq_categories');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFaqEntries({
    int? categoryId,
    String? search,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (categoryId != null) query['category_id'] = categoryId;
      if (search != null && search.isNotEmpty) query['search'] = search;
      final response =
          await _apiClient.dio.get('/faq/entries', queryParameters: query);
      final data = response.data;
      if (page == 1 && categoryId == null && search == null) {
        await _offlineService.saveCache('faq_entries', data);
      }
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('faq_entries');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTags() async {
    try {
      final response = await _apiClient.dio.get('/tags');
      final data = List<Map<String, dynamic>>.from(response.data);
      await _offlineService.saveCache('tags', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('tags');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
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
