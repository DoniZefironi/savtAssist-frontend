import 'package:flutter/material.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/glow_button.dart';
import '../models/cabinet.dart';
import '../main.dart';

class ShuListScreen extends StatefulWidget {
  const ShuListScreen({super.key});

  @override
  State<ShuListScreen> createState() => _ShuListScreenState();
}

class _ShuListScreenState extends State<ShuListScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String _selectedSort = 'По типу';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();
  List<Cabinet> _cabinets = [];
  List<Map<String, dynamic>> _pendingRequests = []; // заявки на модерацию
  bool _isLoading = true;
  String _error = '';

  final List<String> _sortOptions = ['По типу', 'По гарантии', 'По дате'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      // Загружаем активные ШУ
      final cabinets = await cabinetService.getUserCabinets();
      // Загружаем заявки на модерацию
      final requests = await cabinetService.getUserAdditionRequests();
      setState(() {
        _cabinets = cabinets;
        _pendingRequests =
            requests.where((r) => r['status'] == 'pending').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Cabinet> get _filteredAndSortedCabinets {
    var filtered = _cabinets.where((cab) {
      final query = _searchQuery.toLowerCase();
      return cab.type.toLowerCase().contains(query) ||
          cab.objectNumber.toLowerCase().contains(query) ||
          cab.customName.toLowerCase().contains(query);
    }).toList();

    switch (_selectedSort) {
      case 'По типу':
        filtered.sort((a, b) => a.type.compareTo(b.type));
        break;
      case 'По гарантии':
        filtered.sort((a, b) {
          final weightA = _warrantyWeight(a.warrantyStatus);
          final weightB = _warrantyWeight(b.warrantyStatus);
          if (weightA != weightB) return weightB.compareTo(weightA);
          return (a.warrantyEndsAt ?? '').compareTo(b.warrantyEndsAt ?? '');
        });
        break;
      case 'По дате':
        filtered.sort((a, b) => b.cabinetId.compareTo(a.cabinetId));
        break;
    }
    return filtered;
  }

  int _warrantyWeight(String status) {
    switch (status) {
      case 'active':
        return 3;
      case 'expiring_soon':
        return 2;
      case 'expired':
        return 1;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _navigateToAddShu() async {
    await Navigator.pushNamed(context, '/qr-scanner');
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Мои ШУ',
      appBarAction: IconButton(
        icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
            color: Colors.white),
        onPressed: () {
          setState(() {
            _isSearchExpanded = !_isSearchExpanded;
            if (!_isSearchExpanded) _searchQuery = '';
          });
          if (_isSearchExpanded) {
            Future.delayed(const Duration(milliseconds: 100), () {
              FocusScope.of(context).requestFocus(_searchFocusNode);
            });
          } else {
            FocusScope.of(context).unfocus();
          }
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 16, vertical: 12),
                child: Column(
                  children: [
                    GlowButton(
                      text: 'Добавить ШУ',
                      icon: Icons.qr_code_scanner,
                      onPressed: _navigateToAddShu,
                    ),
                    const SizedBox(height: 12),
                    if (_isSearchExpanded) ...[
                      _buildSearchField(isDesktop),
                      const SizedBox(height: 8),
                    ],
                    _buildSortChips(),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Ошибка: $_error'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                    onPressed: _loadData,
                                    child: const Text('Повторить')),
                              ],
                            ),
                          )
                        : (_filteredAndSortedCabinets.isEmpty &&
                                _pendingRequests.isEmpty)
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _filteredAndSortedCabinets.length +
                                    _pendingRequests.length,
                                itemBuilder: (context, index) {
                                  // Сначала отображаем заявки, затем активные ШУ
                                  if (index < _pendingRequests.length) {
                                    return _buildPendingRequestCard(
                                        _pendingRequests[index], index);
                                  }
                                  final cabinetIndex =
                                      index - _pendingRequests.length;
                                  return _buildCabinetCard(
                                      _filteredAndSortedCabinets[cabinetIndex],
                                      cabinetIndex);
                                },
                              ),
              ),
            ],
          );
        },
      ),
      bottomNavBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTapped,
        unreadCounts: const {'chats': 0},
      ),
    );
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> request, int index) {
    final theme = Theme.of(context);
    final photoUrl = request['photo_url'] ?? '';
    final comment = request['user_comment'] ?? '';
    final createdAt = request['created_at'] != null
        ? DateTime.parse(request['created_at']).toLocal()
        : DateTime.now();

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.hourglass_empty, color: Colors.grey, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'На модерации',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.isNotEmpty
                      ? comment
                      : 'Ожидает подтверждения администратором',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Отправлено: ${_formatDate(createdAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.cancel_outlined, color: Colors.red.shade300),
            onPressed: () => _cancelRequest(request['id']),
            tooltip: 'Отменить заявку',
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(int requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content:
            const Text('Заявка на добавление ШУ будет удалена. Продолжить?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Нет')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Да')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await apiClient.dio.delete('/cabinet-addition-requests/$requestId');
        _loadData(); // обновить список
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Заявка отменена'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCabinetCard(Cabinet cabinet, int index) {
    final theme = Theme.of(context);
    final statusColor = _getWarrantyColor(cabinet.warrantyStatus);
    final statusText =
        _getWarrantyText(cabinet.warrantyStatus, cabinet.warrantyEndsAt);
    final statusIcon = _getWarrantyIcon(cabinet.warrantyStatus);
    final displayName =
        cabinet.customName.isNotEmpty ? cabinet.customName : cabinet.type;

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      onTap: () =>
          Navigator.pushNamed(context, '/shu-detail/${cabinet.cabinetId}'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.memory, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  cabinet.objectNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 11),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (cabinet.unreadCount > 0)
            GestureDetector(
              onTap: () async {
                try {
                  final chatData =
                      await cabinetService.getCabinetChat(cabinet.cabinetId);
                  final chatId = chatData['id'];
                  if (chatId != null) {
                    Navigator.pushNamed(context, '/chat/$chatId');
                  } else {
                    throw Exception('Не удалось получить chat_id');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Ошибка открытия чата: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        color: theme.colorScheme.primary, size: 18),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: const Color(0xFF991B1B),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      const Color(0xFF991B1B).withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1)
                            ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDesktop) {
    final theme = Theme.of(context);
    return TextField(
      focusNode: _searchFocusNode,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Поиск по ШУ...',
        hintStyle:
            TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
        prefixIcon: Icon(Icons.search,
            color: theme.colorScheme.onSurfaceVariant, size: 24),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSortChips() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _sortOptions.map((sortOption) {
          final isSelected = _selectedSort == sortOption;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(sortOption),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedSort = sortOption),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 1.5),
              ),
              checkmarkColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              elevation: isSelected ? 4 : 0,
              shadowColor: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : Colors.transparent,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle),
            child: Icon(Icons.qr_code_scanner,
                size: 48, color: theme.colorScheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text('Нет добавленных ШУ',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Отсканируйте QR-код для добавления',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: GlowButton(
              text: 'Сканировать',
              icon: Icons.qr_code_scanner,
              onPressed: () => Navigator.pushNamed(context, '/qr-scanner'),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/knowledge');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/chats');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  Color _getWarrantyColor(String status) {
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

  String _getWarrantyText(String status, String? endsAt) {
    switch (status) {
      case 'active':
        return 'Активна';
      case 'expiring_soon':
        return 'Истекает';
      case 'expired':
        return 'Истекла';
      default:
        return 'Н/Д';
    }
  }

  IconData _getWarrantyIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'expiring_soon':
        return Icons.warning_amber_rounded;
      case 'expired':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }
}
