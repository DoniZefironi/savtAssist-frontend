// lib/screens/shu_detail_screen.dart
import 'package:flutter/material.dart';
import '../utils/file_download.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/animated_card.dart';
import '../widgets/secure_image.dart';
import '../main.dart'; // cabinetService

class ShuDetailScreen extends StatefulWidget {
  final String shuId;
  const ShuDetailScreen({super.key, required this.shuId});

  @override
  State<ShuDetailScreen> createState() => _ShuDetailScreenState();
}

class _ShuDetailScreenState extends State<ShuDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _customNameController;
  late TextEditingController _commentController;
  Map<String, dynamic>? _cabinetDetail;
  List<Map<String, dynamic>> _documents = [];
  List<String> _photos = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadingDocs = false;
  bool _loadingPhotos = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _customNameController = TextEditingController();
    _commentController = TextEditingController();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final detail =
          await cabinetService.getCabinetDetail(int.parse(widget.shuId));
      setState(() {
        _cabinetDetail = detail;
        _customNameController.text = detail['custom_name'] ?? '';
        _commentController.text = detail['custom_comment'] ?? '';
        _isLoading = false;
      });
      _loadDocuments();
      _loadPhotos();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка загрузки: $e');
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocs = true);
    try {
      final docs = await cabinetService.getDocuments(int.parse(widget.shuId));
      setState(() {
        _documents = docs;
        _loadingDocs = false;
      });
    } catch (e) {
      setState(() => _loadingDocs = false);
      _showError('Ошибка загрузки документов: $e');
    }
  }

  Future<void> _loadPhotos() async {
    setState(() => _loadingPhotos = true);
    try {
      final photos = await cabinetService.getPhotos(int.parse(widget.shuId));
      setState(() {
        _photos = photos;
        _loadingPhotos = false;
      });
    } catch (e) {
      setState(() => _loadingPhotos = false);
    }
  }

  Future<void> _downloadDocument(String url, String fileName) async {
    try {
      final parts = url.split('/');
      final docId = int.tryParse(parts[parts.length - 2]);

      if (docId == null) {
        _showError('Не удалось определить ID документа');
        return;
      }

      setState(() => _loadingDocs = true);

      final bytes = await cabinetService.downloadDocumentWithAuth(docId);
      await saveAndOpenFile(bytes, fileName);

      setState(() => _loadingDocs = false);
    } catch (e) {
      setState(() => _loadingDocs = false);
      _showError('Не удалось загрузить или открыть файл: $e');
    }
  }

  Future<void> _saveLocalChanges() async {
    final newName = _customNameController.text;
    final newComment = _commentController.text;
    setState(() => _isSaving = true);
    try {
      await cabinetService.updateCabinet(
        int.parse(widget.shuId),
        customName: newName,
        customComment: newComment,
      );
      setState(() {
        _cabinetDetail?['custom_name'] = newName;
        _cabinetDetail?['custom_comment'] = newComment;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Изменения сохранены'),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Ошибка: $e');
    }
  }

  Future<void> _deleteCabinet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Открепить ШУ'),
        content: const Text(
            'Вы уверены, что хотите открепить это ШУ? Оно исчезнет из вашего списка.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Открепить')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await cabinetService.deleteCabinet(int.parse(widget.shuId));
      if (mounted) {
        Navigator.pop(context); // возврат на список ШУ
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка открепления: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  String get _warrantyText {
    final status = _cabinetDetail?['warranty_status'];
    if (status == 'active') return 'Активна';
    if (status == 'expiring_soon') return 'Истекает';
    if (status == 'expired') return 'Истекла';
    return 'Н/Д';
  }

  Color get _warrantyColor {
    final status = _cabinetDetail?['warranty_status'];
    switch (status) {
      case 'active':
        return const Color(0xFF10B981);
      case 'expiring_soon':
        return const Color(0xFFF59E0B);
      case 'expired':
        return const Color(0xFF991B1B);
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customNameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_cabinetDetail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Не удалось загрузить данные')),
      );
    }

    return GradientScaffold(
      appBarTitle: _cabinetDetail!['custom_name']?.isNotEmpty == true
          ? _cabinetDetail!['custom_name']
          : _cabinetDetail!['type'],
      appBarLeading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      appBarAction: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white),
        onPressed: _deleteCabinet,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    indicatorColor: theme.colorScheme.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Инфо'),
                      Tab(text: 'Документы'),
                      Tab(text: 'Фото'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(),
                        _buildDocumentsTab(),
                        _buildPhotosTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavBar: null,
    );
  }

  Widget _buildInfoTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildServiceButton(),
          const SizedBox(height: 16),
          AnimatedCard(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Произвольное название',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _customNameController,
                  decoration: InputDecoration(
                    hintText: 'Введите название...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Комментарий',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Введите комментарий...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveLocalChanges,
                    child: _isSaving
                        ? const CircularProgressIndicator()
                        : const Text('Сохранить изменения'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Тип станции', _cabinetDetail?['type'] ?? 'Н/Д'),
          const SizedBox(height: 16),
          _buildInfoRow('Предназначение', _cabinetDetail?['purpose'] ?? 'Н/Д'),
          Divider(height: 32, color: theme.colorScheme.outline),
          _buildInfoRow('Дата начала гарантии',
              _cabinetDetail?['warranty_starts_at'] ?? '—'),
          const SizedBox(height: 16),
          _buildInfoRow('Дата окончания гарантии',
              _cabinetDetail?['warranty_ends_at'] ?? '—'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _warrantyColor.withOpacity(0.15),
                  _warrantyColor.withOpacity(0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _warrantyColor.withOpacity(0.2)),
            ),
            child: Center(
                child: Text(_warrantyText,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _warrantyColor))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 140,
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 14))),
        Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14))),
      ],
    );
  }

  Widget _buildServiceButton() {
    final isWarrantyActive = _cabinetDetail?['warranty_status'] == 'active';
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: () =>
            Navigator.pushNamed(context, '/service-request/${widget.shuId}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isWarrantyActive
              ? const Color(0xFF059669)
              : const Color(0xFF054582),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          isWarrantyActive
              ? 'Гарантийное обслуживание'
              : 'Негарантийное обслуживание',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ========== Документы ==========
  Widget _buildDocumentsTab() {
    if (_loadingDocs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_documents.isEmpty) {
      return const Center(child: Text('Нет документов'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final hasAccess = doc['has_access'] ?? false;
        final docId = doc['id'];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(doc['title'] ?? 'Документ'),
            subtitle: Text(doc['file_size_bytes'] != null
                ? '${(doc['file_size_bytes'] / 1024).round()} KB'
                : ''),
            trailing: hasAccess
                ? ElevatedButton(
                    onPressed: () => _downloadDocument(
                        doc['file_url'], doc['title'] ?? 'document'),
                    child: const Text('Скачать'),
                  )
                : OutlinedButton(
                    onPressed: () async {
                      try {
                        await cabinetService.requestDocumentAccess(docId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Запрос на доступ отправлен'),
                              backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        _showError('Ошибка: $e');
                      }
                    },
                    child: const Text('Запросить доступ'),
                  ),
          ),
        );
      },
    );
  }

  // ========== Фото ==========
  Widget _buildPhotosTab() {
    if (_loadingPhotos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_photos.isEmpty) {
      return const Center(child: Text('Нет фотографий'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SecureImage(
            url: _photos[index],
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
