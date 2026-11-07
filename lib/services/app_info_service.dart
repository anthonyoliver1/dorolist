import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInfoService {
  const AppInfoService();

  Future<String> readVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<bool> openExternalLink(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
