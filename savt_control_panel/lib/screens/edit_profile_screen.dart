import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../main.dart'; // apiClient, authService

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _organizationController;

  bool _isLoading = true;
  bool _isSaving = false;
  String _userType = 'individual';
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _organizationController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final data = await authService.getMe();

      setState(() {
        _fullNameController.text = data['full_name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _organizationController.text = data['organization_name'] ?? '';
        _userType = data['user_type'] ?? 'individual';
        _phoneNumber = data['phone'] ?? '';
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      _showError(_getErrorDetail(e));
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка загрузки: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await apiClient.dio.patch('/auth/me', data: {
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        if (_organizationController.text.trim().isNotEmpty)
          'organization_name': _organizationController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль обновлен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      setState(() => _isSaving = false);
      _showError(_getErrorDetail(e));
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Ошибка сохранения: $e');
    }
  }

  Future<void> _changePhoneNumber() async {
    // Шаг 1: ввод нового номера с выбором кода страны
    final newPhone = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final phoneController = TextEditingController();
        String selectedCountryCode = '+375';
        final List<Map<String, dynamic>> countries = [
          {'code': '+375', 'flag': '🇧🇾', 'length': 9},
          {'code': '+7', 'flag': '🇷🇺', 'length': 10},
        ];
        return AlertDialog(
          title: const Text('Смена номера телефона'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Введите новый номер телефона:'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCountryCode,
                        items: countries.map<DropdownMenuItem<String>>((c) {
                          return DropdownMenuItem<String>(
                            value: c['code'] as String,
                            child: Row(
                              children: [
                                Text(c['flag'] as String),
                                const SizedBox(width: 6),
                                Text(c['code'] as String),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => selectedCountryCode = v!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: 'XXXXXXXXX'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                final fullPhone =
                    selectedCountryCode + phoneController.text.trim();
                if (fullPhone.length < 10) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Введите корректный номер')),
                  );
                  return;
                }
                try {
                  await authService.changePhoneStart(fullPhone);
                  Navigator.pop(ctx, fullPhone);
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text('Ошибка: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Отправить код'),
            ),
          ],
        );
      },
    );

    if (newPhone == null || newPhone.isEmpty) return;

    // Шаг 2: ввод SMS-кода
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final codeController = TextEditingController();
        return AlertDialog(
          title: const Text('Подтверждение'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Введите код из SMS, отправленный на номер $newPhone:'),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(hintText: '123456'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                final enteredCode = codeController.text.trim();
                if (enteredCode.length != 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Введите 6-значный код')),
                  );
                  return;
                }
                try {
                  await authService.changePhoneComplete(newPhone, enteredCode);
                  Navigator.pop(ctx, enteredCode);
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text('Ошибка: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Подтвердить'),
            ),
          ],
        );
      },
    );

    if (code != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Номер телефона изменён'),
            backgroundColor: Colors.green),
      );
      _loadProfile();
    }
  }

  String _getErrorDetail(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Произошла ошибка';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Редактировать профиль'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Сохранить',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 50, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'ФИО',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Введите ФИО';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Введите Email';
                  if (!value.contains('@')) return 'Введите корректный Email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _phoneNumber,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _changePhoneNumber,
                  child: const Text('Сменить номер'),
                ),
              ),
              const SizedBox(height: 16),
              if (_userType == 'organization') ...[
                TextFormField(
                  controller: _organizationController,
                  decoration: const InputDecoration(
                    labelText: 'Название организации',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тип аккаунта',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userType == 'organization'
                          ? 'Организация'
                          : 'Физическое лицо',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
