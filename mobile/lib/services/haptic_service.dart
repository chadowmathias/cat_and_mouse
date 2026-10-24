import 'package:flutter/services.dart';

class HapticService {
  static Future<void> pulseSonarCold() async {
    await HapticFeedback.selectionClick();
  }

  static Future<void> pulseSonarWarm() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> pulseSonarHot() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }

  static Future<void> alertDangerZone() async {
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.vibrate();
  }

  static Future<void> alertOverspeed() async {
    await HapticFeedback.vibrate();
  }

  static Future<void> tagSuccess() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
}
