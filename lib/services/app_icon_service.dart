import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('kyotee/app_icon');

  static Future<bool> supportsAlternateIcons() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return false;
    try {
      final supported = await _channel.invokeMethod<bool>(
        'supportsAlternateIcons',
      );
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> currentIconName() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return null;
    try {
      final name = await _channel.invokeMethod<String?>('currentIconName');
      if (name == null || name.isEmpty) return null;
      return name;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setIcon(String? iconName) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    try {
      await _channel.invokeMethod('setIcon', {'iconName': iconName});
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Failed to change app icon.');
    }
  }
}
