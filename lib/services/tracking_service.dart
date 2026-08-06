import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

class TrackingService {
  /// AppTrackingTransparency iznini kontrol eder ve gerekirse kullanıcıdan izin ister.
  static Future<void> init() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // UI hazırlığı için kısa bir bekleme ekliyoruz
        await Future.delayed(const Duration(milliseconds: 200));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('AppTrackingTransparency hatası: $e');
    }
  }
}
