import 'package:flutter/material.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../main.dart'; // knowledgeService, favoritesService

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 1;
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  // Статьи
  List<Map<String, dynamic>> _articles = [];
  bool _loadingArticles = false;
  int _articlesPage = 1;
  bool _hasMoreArticles = true;
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _tags = [];

  // FAQ
  List<Map<String, dynamic>> _faqEntries = [];
  bool _loadingFaq = false;
  int _faqPage = 1;
  bool _hasMoreFaq = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    favoritesService
        .addListener(_onFavoritesChanged); // подписка на изменения избранного
    _loadCategories();
    _loadTags();
    _loadArticles();
    _loadFaq();
  }

  @override
  void dispose() {
    _tabController.dispose();
    favoritesService.removeListener(_onFavoritesChanged); // отписка
    super.dispose();
  }

  void _onFavoritesChanged() {
    setState(() {}); // просто обновить UI (перерисовать звёздочки)
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await knowledgeService.getKbCategories();
      setState(() => _categories = cats);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadTags() async {
    try {
      final tags = await knowledgeService.getTags();
      setState(() => _tags = tags);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadArticles({bool refresh = false}) async {
    if (_loadingArticles) return;
    if (!refresh && !_hasMoreArticles) return;

    setState(() {
      if (refresh) {
        _articlesPage = 1;
        _articles = [];
        _hasMoreArticles = true;
      }
      _loadingArticles = true;
    });

    try {
      final data = await knowledgeService.getKbArticles(
        categoryId: _selectedCategoryId,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: _articlesPage,
        size: 20,
      );
      final newItems = List<Map<String, dynamic>>.from(data['items']);
      setState(() {
        if (_articlesPage == 1) {
          _articles = newItems;
        } else {
          _articles.addAll(newItems);
        }
        _hasMoreArticles = newItems.length == 20;
        _loadingArticles = false;
      });
      if (newItems.isNotEmpty) _articlesPage++;
    } catch (e) {
      setState(() => _loadingArticles = false);
    }
  }

  Future<void> _loadFaq({bool refresh = false}) async {
    if (_loadingFaq) return;
    if (!refresh && !_hasMoreFaq) return;

    setState(() {
      if (refresh) {
        _faqPage = 1;
        _faqEntries = [];
        _hasMoreFaq = true;
      }
      _loadingFaq = true;
    });

    try {
      final data = await knowledgeService.getFaqEntries(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: _faqPage,
        size: 20,
      );
      final newItems = List<Map<String, dynamic>>.from(data['items']);
      setState(() {
        if (_faqPage == 1) {
          _faqEntries = newItems;
        } else {
          _faqEntries.addAll(newItems);
        }
        _hasMoreFaq = newItems.length == 20;
        _loadingFaq = false;
      });
      if (newItems.isNotEmpty) _faqPage++;
    } catch (e) {
      setState(() => _loadingFaq = false);
    }
  }

  Future<void> _onRefresh() async {
    if (_tabController.index == 0) {
      await _loadArticles(refresh: true);
    } else {
      await _loadFaq(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'База знаний',
      appBarAction: IconButton(
        icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
            color: Colors.white),
        onPressed: () {
          setState(() {
            _isSearchExpanded = !_isSearchExpanded;
            if (!_isSearchExpanded) _searchQuery = '';
          });
          if (_isSearchExpanded) {
            // поиск будет применяться при вводе
          }
        },
      ),
      body: Column(
        children: [
          if (_isSearchExpanded) _buildSearchField(),
          _buildCategoryChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFF0a7ac2),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildArticlesTab(),
                  _buildFaqTab(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTapped,
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _loadArticles(refresh: true);
          _loadFaq(refresh: true);
        },
        decoration: InputDecoration(
          hintText: 'Поиск статей и вопросов...',
          prefixIcon:
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Все'),
            selected: _selectedCategoryId == null,
            onSelected: (_) => setState(() {
              _selectedCategoryId = null;
              _loadArticles(refresh: true);
            }),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
                color: _selectedCategoryId == null
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat['name']),
                  selected: _selectedCategoryId == cat['id'],
                  onSelected: (_) => setState(() {
                    _selectedCategoryId = cat['id'];
                    _loadArticles(refresh: true);
                  }),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: _selectedCategoryId == cat['id']
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildArticlesTab() {
    if (_loadingArticles && _articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_articles.isEmpty) {
      return const Center(child: Text('Нет статей'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _articles.length + (_hasMoreArticles ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _articles.length) {
          if (_loadingArticles)
            return const Center(child: CircularProgressIndicator());
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadArticles());
          return const SizedBox.shrink();
        }
        final article = _articles[index];
        return _buildArticleCard(article, index);
      },
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article, int index) {
    final theme = Theme.of(context);
    final isFavorite = favoritesService.isArticleFavorite(article['id']);
    return AnimatedCard(
      index: index,
      onTap: () => _showArticleDetail(article['id']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.menu_book, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(article['title'],
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.onSurfaceVariant),
                onPressed: () =>
                    favoritesService.toggleArticleFavorite(article['id']),
              ),
              if ((article['attachment_count'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(Icons.attach_file,
                      size: 14, color: theme.colorScheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(article['description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (article['tags'] != null && article['tags'].isNotEmpty)
                ...article['tags'].take(2).map<Widget>((tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(tag['name'],
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    )),
              const Spacer(),
              Text(_formatDate(article['created_at']),
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    if (_loadingFaq && _faqEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_faqEntries.isEmpty) {
      return const Center(child: Text('Нет вопросов'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _faqEntries.length + (_hasMoreFaq ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _faqEntries.length) {
          if (_loadingFaq)
            return const Center(child: CircularProgressIndicator());
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadFaq());
          return const SizedBox.shrink();
        }
        final faq = _faqEntries[index];
        return _buildFaqCard(faq, index);
      },
    );
  }

  // ==================== НОВАЯ ВЕРСИЯ _buildFaqCard с избранным ====================
  Widget _buildFaqCard(Map<String, dynamic> faq, int index) {
    final theme = Theme.of(context);
    final isFavorite = favoritesService.isFaqFavorite(faq['id']);
    return AnimatedCard(
      index: index,
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(faq['question'],
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? const Color(0xFFF59E0B)
                      : theme.colorScheme.onSurfaceVariant),
              onPressed: () => favoritesService.toggleFaqFavorite(faq['id']),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(faq['answer'],
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/chat/support'),
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('Перейти в чат'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showArticleDetail(int articleId) async {
    final theme = Theme.of(context);
    try {
      final article = await knowledgeService.getKbArticleDetail(articleId);
      final isFavorite = favoritesService.isArticleFavorite(articleId);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                              color: theme.colorScheme.outline,
                              borderRadius: BorderRadius.circular(2))),
                      IconButton(
                        icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite
                                ? const Color(0xFFF59E0B)
                                : theme.colorScheme.onSurfaceVariant),
                        onPressed: () async {
                          await favoritesService
                              .toggleArticleFavorite(articleId);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(article['title'],
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(article['description'] ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.6)),
                  if (article['attachments'] != null &&
                      article['attachments'].isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Вложения:', style: theme.textTheme.titleSmall),
                    ...article['attachments'].map<Widget>((att) => ListTile(
                          title: Text(att['title']),
                          trailing: ElevatedButton(
                            onPressed: () => knowledgeService
                                .downloadKbAttachment(articleId, att['id']),
                            child: const Text('Скачать'),
                          ),
                        )),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/chat/support'),
                      icon: const Icon(Icons.chat),
                      label: const Text('Перейти в чат'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red));
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final date = DateTime.parse(iso);
      return '${date.day}.${date.month}.${date.year}';
    } catch (_) {
      return '';
    }
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/shu-list');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/chats');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }
}
