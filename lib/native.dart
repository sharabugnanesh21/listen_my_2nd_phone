import 'dart:convert';

import 'package:flutter/services.dart';

/// Live stream of captured notifications (native service -> Flutter).
const EventChannel notifChannel =
    EventChannel('com.perkypet.listen_my_phone/notifications');

const MethodChannel _control =
    MethodChannel('com.perkypet.listen_my_phone/control');

/// One captured notification (mirrors the native JSON stored by AppStore).
class CapturedEvent {
  CapturedEvent({
    required this.id,
    required this.package,
    required this.appName,
    required this.title,
    required this.text,
    required this.time,
  });

  final String id;
  final String package;
  final String appName;
  final String title;
  final String text;
  final DateTime time;

  factory CapturedEvent.fromMap(Map<String, dynamic> m) {
    final appName = m['appName'] as String?;
    final package = m['package'] as String? ?? '';
    return CapturedEvent(
      id: m['id'] as String? ?? '',
      package: package,
      appName: (appName != null && appName.isNotEmpty) ? appName : package,
      title: m['title'] as String? ?? '',
      text: m['text'] as String? ?? '',
      time: DateTime.fromMillisecondsSinceEpoch(
          (m['timestamp'] as num?)?.toInt() ?? 0),
    );
  }
}

/// Thin wrapper around the native control MethodChannel.
class Native {
  static Future<bool> isAccessGranted() async =>
      await _control.invokeMethod<bool>('isAccessGranted') ?? false;

  static Future<void> openAccessSettings() =>
      _control.invokeMethod<void>('openAccessSettings');

  static Future<void> openSoundSettings() =>
      _control.invokeMethod<void>('openSoundSettings');

  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final raw =
        await _control.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Uint8List?> getAppIcon(String package) async {
    final b64 = await _control.invokeMethod<String>('getAppIcon', package);
    return b64 == null ? null : base64Decode(b64);
  }

  static Future<Set<String>> getEnabledPackages() async {
    final list =
        await _control.invokeMethod<List<dynamic>>('getEnabledPackages') ?? [];
    return list.map((e) => e as String).toSet();
  }

  static Future<void> setEnabledPackages(Set<String> packages) =>
      _control.invokeMethod<void>('setEnabledPackages', packages.toList());

  static Future<bool> getCaptureAll() async =>
      await _control.invokeMethod<bool>('getCaptureAll') ?? false;

  static Future<void> setCaptureAll(bool value) =>
      _control.invokeMethod<void>('setCaptureAll', value);

  static Future<List<CapturedEvent>> getEvents() async {
    final jsonStr = await _control.invokeMethod<String>('getEvents') ?? '[]';
    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded
        .map((e) => CapturedEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> removeEvent(String id) =>
      _control.invokeMethod<void>('removeEvent', id);

  static Future<void> clearEvents() =>
      _control.invokeMethod<void>('clearEvents');
}
