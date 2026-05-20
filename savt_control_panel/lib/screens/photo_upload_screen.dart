import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final TextEditingController _objectNumberController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1200);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = picked;
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _submitForReview() async {
    final objectNumber = _objectNumberController.text.trim();
    if (objectNumber.isEmpty) {
      _showError('Введите номер объекта');
      return;
    }
    if (_selectedImage == null) {
      _showError('Сделайте фото наклейки');
      return;
    }

    setState(() => _isLoading = true);

    try {
      setState(() => _isUploading = true);
      final photoUrl = await uploadService.uploadAttachment(_selectedImage!);
      setState(() => _isUploading = false);

      await cabinetService.addCabinetByPhoto(
        photoUrl,
        userComment: _commentController.text.trim(),
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
                Text('Фото отправлено на проверку!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Обработка заявки занимает 1-2 рабочих дня',
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
    _objectNumberController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Отправка фото наклейки'),
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
                color: const Color(0xFF054582).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF054582).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF054582), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Для старых моделей ШУ без QR-кода отправьте фото заводской наклейки. Мы добавим ваше устройство вручную.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Номер объекта',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _objectNumberController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Например: ОБ-2024-001',
                      hintStyle:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Указан на наклейке или в документах',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Text('Фото наклейки',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  if (_selectedImageBytes == null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Сделать фото'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF054582),
                            foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Выбрать из галереи'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF054582)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.colorScheme.outline, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            Image.memory(
                              _selectedImageBytes!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _removeImage,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF991B1B),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Фото должно быть четким, все данные должны читаться',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 20),
                  Text('Комментарий (необязательно)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Дополнительная информация...',
                      hintStyle:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _selectedImage == null)
                          ? null
                          : _submitForReview,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF054582),
                          foregroundColor: Colors.white),
                      child: _isLoading
                          ? (_isUploading
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white)),
                                      SizedBox(height: 4),
                                      Text('Загрузка фото...',
                                          style: TextStyle(fontSize: 12)),
                                    ])
                              : const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)))
                          : const Text('Отправить на проверку',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Обработка заявки занимает 1-2 рабочих дня',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
