import 'dart:io';
import 'package:flutter/services.dart';

typedef TimerNotificationAction = void Function(
    String action, String sessionId);

class SessionLiveActivity {
  Future<void> initialize(VoidCallback onOpenFocus,
      {TimerNotificationAction? onAction}) async {}
  Future<void> sync(Map<String, Object?>? state) async {}
  void dispose() {}
}

class NativeSessionLiveActivity extends SessionLiveActivity {
  static const channel = MethodChannel('doro_list/pomodoro_live_activity');

  @override
  Future<void> initialize(VoidCallback onOpenFocus,
      {TimerNotificationAction? onAction}) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    void handleAction(dynamic data) {
      if (data is! Map) return;
      final action = data['action'];
      final id = data['sessionId'];
      if (action is! String || id is! String) return;
      onOpenFocus();
      if (action != 'open') onAction?.call(action, id);
    }

    channel.setMethodCallHandler((call) async {
      if (call.method == 'openFocus') onOpenFocus();
      if (call.method == 'timerAction') handleAction(call.arguments);
    });
    if (Platform.isAndroid) {
      handleAction(await channel.invokeMethod<dynamic>('initialize'));
    } else if (await channel.invokeMethod<bool>('initialize') == true) {
      onOpenFocus();
    }
  }

  @override
  Future<void> sync(Map<String, Object?>? state) async {
    if (Platform.isIOS || Platform.isAndroid) {
      await channel.invokeMethod<void>('sync', state);
    }
  }

  @override
  void dispose() {
    if (Platform.isIOS || Platform.isAndroid) {
      channel.setMethodCallHandler(null);
    }
  }
}
