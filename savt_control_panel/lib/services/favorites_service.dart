// lib/services/favorites_service.dart
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class FavoritesService extends ChangeNotifier {
  final ApiClient _apiClient;
  Set<int> _favoriteArticleIds = {};
  Set<int> _favoriteFaqIds = {}; // добавлено

  FavoritesService(this._apiClient);

  Future<void> loadFavorites() async {
    try {
      final articles =
          await _apiClient.dio.get('/favorites?entity_type=kb_article');
      final faqs = await _apiClient.dio.get('/favorites?entity_type=faq_entry');
      _favoriteArticleIds = Set.from(
          (articles.data['items'] as List).map((e) => e['entity_id'] as int));
      _favoriteFaqIds = Set.from(
          (faqs.data['items'] as List).map((e) => e['entity_id'] as int));
      notifyListeners();
    } catch (e) {
      // игнорируем
    }
  }

  // Статьи
  Future<void> toggleArticleFavorite(int articleId) async {
    if (_favoriteArticleIds.contains(articleId)) {
      await _apiClient.dio.delete('/favorites/kb_article/$articleId');
      _favoriteArticleIds.remove(articleId);
    } else {
      await _apiClient.dio.post('/favorites',
          data: {'entity_type': 'kb_article', 'entity_id': articleId});
      _favoriteArticleIds.add(articleId);
    }
    notifyListeners();
  }

  bool isArticleFavorite(int articleId) =>
      _favoriteArticleIds.contains(articleId);
  Set<int> get favoriteArticleIds => _favoriteArticleIds;

  // FAQ
  Future<void> toggleFaqFavorite(int faqId) async {
    if (_favoriteFaqIds.contains(faqId)) {
      await _apiClient.dio.delete('/favorites/faq_entry/$faqId');
      _favoriteFaqIds.remove(faqId);
    } else {
      await _apiClient.dio.post('/favorites',
          data: {'entity_type': 'faq_entry', 'entity_id': faqId});
      _favoriteFaqIds.add(faqId);
    }
    notifyListeners();
  }

  bool isFaqFavorite(int faqId) => _favoriteFaqIds.contains(faqId);
  Set<int> get favoriteFaqIds => _favoriteFaqIds;
}
