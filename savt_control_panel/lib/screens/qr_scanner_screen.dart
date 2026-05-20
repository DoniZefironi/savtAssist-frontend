import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart'; // cabinetService

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController scannerController = MobileScannerController();
  final TextEditingController _manualCodeController = TextEditingController();
  String _error = '';
  bool _isProcessing = false;

  @override
  void dispose() {
    scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  void _onQRDetected(BarcodeCapture capture) {
    if (_isProcessing) return;
    final String? code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      _isProcessing = true;
      _processQrCode(code);
    }
  }

  Future<void> _processQrCode(String qrData) async {
    try {
      final result = await cabinetService.addCabinetByQr(qrData);
      if (result['status'] == 'linked') {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title:
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
              content: const Text('ШУ успешно добавлено!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // вернуться на список ШУ
                  },
                  child: const Text('ОК'),
                ),
              ],
            ),
          );
        }
      } else if (result['status'] == 'request_submitted') {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Icon(Icons.info_outline,
                  color: Colors.orange, size: 48),
              content: const Text(
                  'Запрос на добавление ШУ отправлен администратору.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('ОК'),
                ),
              ],
            ),
          );
        }
      } else {
        _showError(result['message'] ?? 'Неизвестная ошибка');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) _isProcessing = false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleManualSubmit() async {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите код ШУ');
      return;
    }
    setState(() => _error = '');
    _isProcessing = true;
    await _processQrCode(code);
    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить ШУ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: scannerController,
              onDetect: _onQRDetected,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Или введите код вручную',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualCodeController,
                    decoration: InputDecoration(
                      hintText: 'Введите код с наклейки',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _handleManualSubmit,
                    child: const Text('Добавить по коду'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
