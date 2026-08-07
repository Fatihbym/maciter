import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class TrackingService {
  /// WebView açıldıktan sonra ATT iznini ister ve kullanıcı izin vermezse çerez iznini reddedip banner'ı siler.
  static Future<void> checkATTAndHandleCookies(InAppWebViewController? controller) async {
    try {
      TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future.delayed(const Duration(milliseconds: 300));
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }

      if (status == TrackingStatus.denied || status == TrackingStatus.restricted) {
        rejectAndRemoveCookieBanner(controller);
      }
    } catch (e) {
      debugPrint("ATT Error: $e");
    }
  }

  static Future<void> handleCookiesIfATTDenied(InAppWebViewController? controller) async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.denied || status == TrackingStatus.restricted) {
        rejectAndRemoveCookieBanner(controller);
      }
    } catch (e) {
      debugPrint("ATT Check Error: $e");
    }
  }

  static void rejectAndRemoveCookieBanner(InAppWebViewController? controller) {
    if (controller == null) return;
    const jsCode = """
      (function() {
        function tryRejectCookies() {
          var rejectBtn = document.getElementById('cookieReject');
          if (rejectBtn) {
            rejectBtn.click();
          }
          var banner = document.getElementById('cookieBanner');
          if (banner) {
            banner.style.display = 'none';
            banner.remove();
          }
        }
        
        tryRejectCookies();

        var attempts = 0;
        var interval = setInterval(function() {
          attempts++;
          tryRejectCookies();
          if (attempts >= 10 || !document.getElementById('cookieBanner')) {
            clearInterval(interval);
          }
        }, 300);
      })();
    """;
    controller.evaluateJavascript(source: jsCode);
  }
}
