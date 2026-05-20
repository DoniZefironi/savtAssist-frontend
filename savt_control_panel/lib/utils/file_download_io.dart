import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<void> saveAndOpenFile(List<int> bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final savePath = '${directory.path}/$fileName';
  final file = File(savePath);
  await file.writeAsBytes(bytes);
  final result = await OpenFile.open(savePath);
  if (result.type != ResultType.done) {
    throw Exception('Не удалось открыть файл: ${result.message}');
  }
}
