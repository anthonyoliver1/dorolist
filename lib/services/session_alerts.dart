import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

int notificationId(String sessionId) => sessionId.codeUnits
    .fold(17, (value, unit) => (value * 31 + unit) & 0x7fffffff);

// A no-op implementation is also useful for tests and unsupported platforms.
class SessionAlerts {
  Future<void> initialize() async {}
  Future<String?> schedule(
          {required String sessionId,
          required DateTime deadline,
          required String title,
          required String body,
          bool requestPermissions = true}) async =>
      null;
  Future<void> cancel(String sessionId) async {}
  Future<void> completed(
      {required String sessionId,
      required String title,
      required String body,
      required bool foreground}) async {}
}

class NativeSessionAlerts extends SessionAlerts {
  NativeSessionAlerts({this.onOpenFocus});
  final VoidCallback? onOpenFocus;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _askedExact = false;
  final Map<String, bool> _scheduled = {};
  bool get _supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('pomodoro_end_v1', 'Fim das sessões',
        channelDescription: 'Avisos de término do foco e das pausas',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: 'ic_stat_timer'),
    iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBanner: true,
        presentList: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  @override
  Future<void> initialize() => _initialize();

  Future<void> _initialize() async {
    if (_initialized || !_supported) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
        onDidReceiveNotificationResponse: (_) => onOpenFocus?.call(),
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_timer'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestSoundPermission: false,
              requestBadgePermission: false),
          macOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestSoundPermission: false,
              requestBadgePermission: false),
        ));
    _initialized = true;
    var exact = true;
    if (Platform.isAndroid) {
      exact = await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()!
              .canScheduleExactNotifications() ??
          false;
    }
    for (final request in await _plugin.pendingNotificationRequests()) {
      if (request.payload != null) _scheduled[request.payload!] = exact;
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) onOpenFocus?.call();
  }

  @override
  Future<String?> schedule(
      {required String sessionId,
      required DateTime deadline,
      required String title,
      required String body,
      bool requestPermissions = true}) async {
    if (!_supported) return 'Neste sistema, o aviso funciona com o app aberto.';
    await _initialize();
    var allowed = true;
    var exact = true;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()!;
      allowed = requestPermissions
          ? await android.requestNotificationsPermission() ?? false
          : await android.areNotificationsEnabled() ?? false;
      exact = await android.canScheduleExactNotifications() ?? false;
      if (requestPermissions && allowed && !exact && !_askedExact) {
        _askedExact = true;
        exact = await android.requestExactAlarmsPermission() ?? false;
      }
    } else if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()!;
      allowed = requestPermissions
          ? await ios.requestPermissions(alert: true, sound: true) ?? false
          : (await ios.checkPermissions())?.isEnabled ?? false;
    } else {
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()!;
      allowed = requestPermissions
          ? await mac.requestPermissions(alert: true, sound: true) ?? false
          : (await mac.checkPermissions())?.isEnabled ?? false;
    }
    if (!allowed) {
      return 'Notificações desativadas. O aviso sonoro funciona com o app aberto.';
    }
    if (!deadline.isAfter(DateTime.now())) return null;
    await _plugin.zonedSchedule(
        id: notificationId(sessionId),
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(deadline.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: sessionId);
    _scheduled[sessionId] = exact;
    return exact
        ? null
        : 'O Android pode atrasar o aviso em segundo plano. Permita alarmes exatos nos ajustes do sistema.';
  }

  @override
  Future<void> cancel(String sessionId) async {
    if (!_supported) return;
    await _initialize();
    await _plugin.cancel(id: notificationId(sessionId));
    _scheduled.remove(sessionId);
  }

  @override
  Future<void> completed(
      {required String sessionId,
      required String title,
      required String body,
      required bool foreground}) async {
    if (!foreground) return;
    await HapticFeedback.mediumImpact();
    final exact = _scheduled.remove(sessionId);
    if (exact == false) {
      await _plugin.cancel(id: notificationId(sessionId));
      await _plugin.show(
          id: notificationId(sessionId),
          title: title,
          body: body,
          notificationDetails: _details);
    } else if (exact == null) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }
}
