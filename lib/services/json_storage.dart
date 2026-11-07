import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class JsonStorage {
  JsonStorage(this.name, {Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;
  final String name;
  final Future<Directory> Function() _directory;
  Future<void> _pending = Future.value();

  Future<Map<String, dynamic>?> read() async {
    final file = File('${(await _directory()).path}/$name');
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString());
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Arquivo inválido');
    }
    return data;
  }

  Future<void> save(Map<String, dynamic> data) {
    final content = jsonEncode(data);
    final write = _pending.then((_) async {
      final file = File('${(await _directory()).path}/$name');
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(content, flush: true);
      await temporary.rename(file.path);
    });
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
