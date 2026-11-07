import 'package:flutter/foundation.dart';

import '../services/app_info_service.dart';

class AboutViewModel extends ChangeNotifier {
  AboutViewModel({AppInfoService service = const AppInfoService()})
      : _service = service {
    _version = _readVersionLabel();
  }

  static final portfolioUrl = Uri.https('by-anthony-oliveira.vercel.app', '/');

  final AppInfoService _service;
  late Future<String> _version;

  Future<String> get version => _version;

  Future<String> _readVersionLabel() async {
    final version = await _service.readVersion();
    return version.isEmpty ? 'Versão indisponível' : 'Versão $version';
  }

  void retryVersion() {
    _version = _readVersionLabel();
    notifyListeners();
  }

  Future<bool> openPortfolio() async {
    try {
      return await _service.openExternalLink(portfolioUrl);
    } catch (_) {
      return false;
    }
  }
}
