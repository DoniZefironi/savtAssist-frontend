// lib/screens/service_request_screen.dart
import 'package:flutter/material.dart';
import '../main.dart'; // serviceRequestService, cabinetService

class ServiceRequestScreen extends StatefulWidget {
  final String shuId;
  const ServiceRequestScreen({super.key, required this.shuId});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String _requestType = 'repair';
  bool _isLoading = false;
  Map<String, dynamic>? _cabinetDetail;

  // Типы заявок
  final List<Map<String, dynamic>> _requestTypes = [
    {'value': 'repair', 'label': 'Ремонт', 'icon': Icons.build_outlined},
    {
      'value': 'maintenance',
      'label': 'Техническое обслуживание',
      'icon': Icons.manage_search
    },
    {
      'value': 'inspection',
      'label': 'Инспекция',
      'icon': Icons.visibility_outlined
    },
    {'value': 'other', 'label': 'Другое', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _loadCabinetInfo();
  }

  Future<void> _loadCabinetInfo() async {
    try {
      final detail =
          await cabinetService.getCabinetDetail(int.parse(widget.shuId));
      setState(() {
        _cabinetDetail = detail;
        // По умолчанию repair для гарантийных, maintenance для негарантийных
        _requestType =
            detail['warranty_status'] == 'active' ? 'repair' : 'maintenance';
      });
    } catch (e) {
      // игнорируем, работаем дальше
    }
  }

  Future<void> _submitRequest() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showError('Опишите проблему перед отправкой');
      return;
    }
    if (description.length < 10) {
      _showError('Описание должно быть не менее 10 символов');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await serviceRequestService.createServiceRequest(
        cabinetId: int.parse(widget.shuId),
        requestType: _requestType,
        description: description,
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Icon(Icons.check_circle,
                color: Color(0xFF10B981), size: 48),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                Text('Заявка отправлена!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Мы свяжемся с вами в течение 24 часов',
                    textAlign: TextAlign.center),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Хорошо',
                      style: TextStyle(color: Color(0xFF054582))),
                ),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Заявка на обслуживание'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.devices_other,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Оборудование',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        Text(_cabinetDetail?['type'] ?? 'Загрузка...',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Тип заявки',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _requestType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: _requestTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type['value'] as String?,
                        child: Row(
                          children: [
                            Icon(
                              type['icon'] as IconData,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(type['label'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _requestType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getRequestTypeDescription(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Описание проблемы',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText:
                          'Опишите подробно проблему, с которой вы столкнулись...',
                      hintMaxLines: 3,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Чем подробнее описание, тем быстрее мы сможем помочь',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF054582),
                    foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Отправить заявку',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Что дальше?',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildStep(1, 'Специалист рассмотрит вашу заявку'),
                  const SizedBox(height: 8),
                  _buildStep(2, 'Мы свяжемся с вами для уточнения деталей'),
                  const SizedBox(height: 8),
                  _buildStep(3, 'Согласуем дату и время визита мастера'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRequestTypeDescription() {
    switch (_requestType) {
      case 'repair':
        return 'Заявка на ремонт оборудования. Будет рассмотрена в приоритетном порядке.';
      case 'maintenance':
        return 'Заявка на техническое обслуживание. Регулярные работы по обслуживанию.';
      case 'inspection':
        return 'Заявка на инспекцию/проверку оборудования.';
      case 'other':
        return 'Другой тип заявки. Опишите детали в описании.';
      default:
        return '';
    }
  }

  Widget _buildStep(int number, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: theme.colorScheme.primary, shape: BoxShape.circle),
          child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13))),
      ],
    );
  }
}
