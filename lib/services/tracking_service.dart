import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class TrackingService {
  static Future<bool> isATTDenied() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      return status == TrackingStatus.denied || status == TrackingStatus.restricted;
    } catch (_) {
      return false;
    }
  }

  /// WebView açıldıktan sonra ATT iznini ister ve kullanıcı izin vermezse çerez iznini reddedip 3. taraf çerezleri engeller.
  static Future<void> checkATTAndHandleCookies(InAppWebViewController? controller) async {
    try {
      TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future.delayed(const Duration(milliseconds: 300));
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }

      if (status == TrackingStatus.denied || status == TrackingStatus.restricted) {
        await applyStrictPrivacyMode(controller);
      }
    } catch (e) {
      debugPrint("ATT Error: $e");
    }
  }

  static Future<void> handleCookiesIfATTDenied(InAppWebViewController? controller) async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.denied || status == TrackingStatus.restricted) {
        await applyStrictPrivacyMode(controller);
      }
    } catch (e) {
      debugPrint("ATT Check Error: $e");
    }
  }

  static Future<void> applyStrictPrivacyMode(InAppWebViewController? controller) async {
    if (controller == null) return;

    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(thirdPartyCookiesEnabled: false),
      );
    } catch (e) {
      debugPrint("Error disabling thirdPartyCookies: $e");
    }

    const jsCode = """
      (function() {
        // Disable Google Analytics & Tag Manager tracking
        window['ga-disable-UA-'] = true;
        window['ga-disable-G-'] = true;
        if (typeof window.gtag === 'function') {
          window.gtag('consent', 'default', {
            'ad_storage': 'denied',
            'analytics_storage': 'denied',
            'ad_user_data': 'denied',
            'ad_personalization': 'denied'
          });
        }
        
        function tryRejectCookies() {
          var rejectBtn = document.getElementById('cookieReject') || document.getElementById('cookieAcceptNecessary');
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
    await controller.evaluateJavascript(source: jsCode);
  }
}
