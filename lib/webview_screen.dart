import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'dart:io';

import 'services/deep_link_service.dart';
import 'services/js_interceptor_service.dart';
import 'services/auth_service.dart';
import 'services/tracking_service.dart';
import 'screens/login_screen.dart';

class WebViewScreen extends StatefulWidget {
  final DeepLinkService deepLinkService;

  const WebViewScreen({super.key, required this.deepLinkService});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  bool _isReloading = false;
  bool _isFirstLoad = true;
  bool _hasInternet = true;
  bool _pageError = false;
  bool _showScrollToTop = false;
  bool _cartHasItems = false;
  String _currentUrl = "https://bayi.maciterkuafortoptan.com/";
  DateTime? currentBackPressTime;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late final StreamSubscription<Uri> _deepLinkSubscription;
  final JsInterceptorService _jsInterceptorService = JsInterceptorService();
  late PullToRefreshController pullToRefreshController;

  bool get _isHomePage {
    final cleanUrl = _currentUrl.endsWith('/') ? _currentUrl.substring(0, _currentUrl.length - 1) : _currentUrl;
    return cleanUrl == "https://bayi.maciterkuafortoptan.com";
  }

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.black87,
        backgroundColor: Colors.white,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          _webViewController?.reload();
        } else if (Platform.isIOS) {
          _webViewController?.loadUrl(urlRequest: URLRequest(url: await _webViewController?.getUrl()));
        }
      },
    );
    
    // Listen for deep links
    _deepLinkSubscription = widget.deepLinkService.uriStream.listen((Uri uri) {
      if (_webViewController != null) {
        _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectivity(results);
    });

    Connectivity().checkConnectivity().then((results) {
      _updateConnectivity(results);
    });
  }

  Future<bool> _checkActualInternet() async {
    try {
      final result = await InternetAddress.lookup('bayi.maciterkuafortoptan.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _updateConnectivity(List<ConnectivityResult> results) async {
    bool hasInternet = results.any((r) => r != ConnectivityResult.none);
    if (!hasInternet) {
      hasInternet = await _checkActualInternet();
    }
    if (mounted && _hasInternet != hasInternet) {
      setState(() {
        _hasInternet = hasInternet;
      });
      if (hasInternet && !_isFirstLoad) {
        _webViewController?.reload();
      }
    }
  }

  Future<void> _manualCheckConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    await _updateConnectivity(results);
    if (_hasInternet) {
      _webViewController?.reload();
    }
  }



  void _reloadPage() {
    setState(() {
      _isReloading = true;
    });
    _webViewController?.reload();
  }

  Future<void> _openWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/905325165052?text=Merhaba%2C+ben+BYM+B2C+TEST+CAR%C4%B0+isimli+bayinizim.+B2B+platformu+konusunda+destek+rica+edebilir+miyim%3F');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch WhatsApp');
    }
  }

  void _scrollToTop() {
    _webViewController?.evaluateJavascript(source: "window.scrollTo({top: 0, behavior: 'smooth'});");
  }

  void _toggleCart() {
    _webViewController?.evaluateJavascript(source: """
      var basketEl = document.getElementById('basketSummaryOffcanvas');
      if (basketEl) {
        if (typeof bootstrap !== 'undefined') {
          var bsOffcanvas = bootstrap.Offcanvas.getInstance(basketEl);
          if (!bsOffcanvas) {
            bsOffcanvas = new bootstrap.Offcanvas(basketEl);
          }
          bsOffcanvas.toggle();
        } else {
          if (basketEl.classList.contains('show')) {
            basketEl.classList.remove('show');
            basketEl.style.visibility = 'hidden';
            var backdrop = document.querySelector('.offcanvas-backdrop');
            if (backdrop) backdrop.remove();
          } else {
            basketEl.classList.add('show');
            basketEl.style.visibility = 'visible';
          }
        }
      }
    """);
  }

  Widget _buildErrorScreen() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle, size: 80, color: Colors.red.shade400),
          const SizedBox(height: 20),
          const Text(
            "Sayfa Yüklenemedi",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "Aradığınız sayfa şu anda mevcut değil veya bir bağlantı sorunu yaşandı.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _pageError = false;
              });
              _webViewController?.reload();
            },
            icon: const Icon(CupertinoIcons.refresh),
            label: const Text("Tekrar Dene"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _deepLinkSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasInternet) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.wifi_exclamationmark, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text(
                  "İnternet Bağlantısı Yok",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Bağlantı sağlandığında uygulama devam edecektir.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _manualCheckConnectivity,
                  icon: const Icon(CupertinoIcons.refresh),
                  label: const Text("Tekrar Dene"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        if (_webViewController != null && await _webViewController!.canGoBack()) {
          bool shouldGoBack = true;
          WebHistory? history = await _webViewController!.getCopyBackForwardList();
          if (history != null && history.currentIndex != null && history.currentIndex! > 0) {
            WebHistoryItem? prevItem = history.list![history.currentIndex! - 1];
            if (prevItem.url?.toString().contains('/b2b/giris') ?? false) {
              shouldGoBack = false;
            }
          }
          
          if (shouldGoBack) {
            _webViewController!.goBack();
            return;
          }
        }

        DateTime now = DateTime.now();
        if (currentBackPressTime == null || 
            now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
          currentBackPressTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Çıkmak için tekrar geri tuşuna basın.'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.orange, size: 28),
                  SizedBox(width: 10),
                  Text('Çıkış Onayı'),
                ],
              ),
              content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.xmark, color: Colors.red),
                  label: const Text('İptal', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => SystemNavigator.pop(),
                  icon: const Icon(CupertinoIcons.checkmark_alt, color: Colors.green),
                  label: const Text('Çıkış', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: false,
        extendBody: false,
        backgroundColor: Colors.white,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: SafeArea(
            child: Stack(
              children: [
                InAppWebView(
                  pullToRefreshController: pullToRefreshController,
                  initialUrlRequest: URLRequest(
                    url: WebUri("https://bayi.maciterkuafortoptan.com/"),
                    headers: {
                      if (AuthService().sessionCookie != null)
                        'Cookie': AuthService().sessionCookie!
                    }
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    thirdPartyCookiesEnabled: false,
                    sharedCookiesEnabled: true,
                    useShouldInterceptAjaxRequest: true,
                    useShouldInterceptFetchRequest: true,
                    allowsInlineMediaPlayback: true,
                    useShouldOverrideUrlLoading: true,
                    allowsBackForwardNavigationGestures: true,
                    userAgent: AuthService.customUserAgent,
                  ),
                  initialUserScripts: UnmodifiableListView([
                    UserScript(
                      source: """
                        (function() {
                          var style = document.createElement('style');
                          style.id = 'bym-cookie-hide-style';
                          style.innerHTML = '#cookieBanner, .cookie-banner { display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }';
                          if (document.head) {
                            document.head.appendChild(style);
                          } else {
                            document.addEventListener('DOMContentLoaded', function() {
                              if (document.head) document.head.appendChild(style);
                            });
                          }
                        })();
                      """,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  onWebViewCreated: (controller) async {
                    _webViewController = controller;
                    await AuthService().syncCookiesToWebView();
                    controller.addJavaScriptHandler(handlerName: 'CartStatusHandler', callback: (args) {
                      if (args.isNotEmpty) {
                        bool hasItems = args[0] == true;
                        if (mounted && _cartHasItems != hasItems) {
                          setState(() {
                            _cartHasItems = hasItems;
                          });
                        }
                      }
                    });
                  },
                  onScrollChanged: (controller, x, y) {
                    final bool isScrolled = y > 100;
                    if (isScrolled != _showScrollToTop) {
                      setState(() {
                        _showScrollToTop = isScrolled;
                      });
                    }
                  },
                  onLoadStart: (controller, url) async {
                    setState(() {
                      _pageError = false;
                      _showScrollToTop = false;
                    });
                    if (url != null) {
                      final urlStr = url.toString();
                      if (urlStr.contains('/b2b/giris')) {
                         await AuthService().logout();
                         if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(deepLinkService: widget.deepLinkService)
                              ),
                              (route) => false,
                            );
                         }
                         return;
                      }
                      setState(() {
                        _currentUrl = urlStr;
                      });
                    }
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    if (url != null) {
                      setState(() {
                        _currentUrl = url.toString();
                      });
                    }
                  },
                  onLoadStop: (controller, url) async {
                    if (url != null) {
                      setState(() {
                        _currentUrl = url.toString();
                      });
                    }
                    if (_isFirstLoad) {
                      FlutterNativeSplash.remove();
                      _isFirstLoad = false;
                      TrackingService.checkATTAndHandleCookies(controller);
                    } else {
                      TrackingService.handleCookiesIfATTDenied(controller);
                    }
                    pullToRefreshController.endRefreshing();
                    if (_isReloading) {
                      setState(() {
                        _isReloading = false;
                      });
                    }

                    // Eğer giriş sayfasından sonra başka bir sayfaya geçildiyse web geçmişini tamamen sil. 
                    // Böylece kullanıcı donanımsal geri tuşuna veya iOS kaydırma hareketine (swipe-back) bastığında giriş ekranına DÖNEMEZ.
                    if (!_currentUrl.contains('/b2b/giris')) {
                      WebHistory? history = await controller.getCopyBackForwardList();
                      if (history != null && history.list != null) {
                        bool hasLogin = history.list!.any((item) => item.url?.toString().contains('/b2b/giris') ?? false);
                        if (hasLogin) {
                          await controller.clearHistory();
                        }
                      }
                    }
                    
                    // Inject JS to hide original buttons and add padding so bottom content is visible
                    final bool isLoginPage = _currentUrl.contains('/b2b/giris');
                    final String paddingJs = isLoginPage 
                        ? "" 
                        : """
                          var style = document.getElementById('bym-flutter-style');
                          if (!style) {
                              style = document.createElement('style');
                              style.id = 'bym-flutter-style';
                              style.innerHTML = `
                                  #basketSummaryOffcanvas {
                                      bottom: 90px !important;
                                      height: calc(100% - 90px) !important;
                                  }
                                  #cookieBanner, .cookie-banner {
                                      display: none !important;
                                      visibility: hidden !important;
                                      opacity: 0 !important;
                                      pointer-events: none !important;
                                  }
                                  .fixed-bottom, .sticky-bottom, [class*="bottom-nav"] {
                                      bottom: 90px !important;
                                  }
                                  .whatsapp-float, #scrollToTopBtn {
                                      display: none !important;
                                  }
                                  html, body {
                                      height: auto !important;
                                      min-height: 100%;
                                  }
                                  #bym-flutter-spacer {
                                      height: 100px;
                                      width: 100%;
                                      background-color: #ffffff;
                                      display: block;
                                      clear: both;
                                  }
                              `;
                              document.head.appendChild(style);
                          }

                          var spacer = document.getElementById('bym-flutter-spacer');
                          if (!spacer) {
                              spacer = document.createElement('div');
                              spacer.id = 'bym-flutter-spacer';
                              document.body.appendChild(spacer);
                          }
                        """;
                    
                    await controller.evaluateJavascript(source: paddingJs);

                    if (_currentUrl.contains('/sepet/detay')) {
                      await controller.evaluateJavascript(source: """
                        function checkCart() {
                           var hasItems = document.querySelectorAll('.basket-item-card').length > 0;
                           if (window.flutter_inappwebview) {
                             window.flutter_inappwebview.callHandler('CartStatusHandler', hasItems);
                           }
                        }
                        checkCart();
                        if (!window.cartObserverAdded) {
                           var observer = new MutationObserver(function(mutations) {
                              checkCart();
                           });
                           observer.observe(document.body, { childList: true, subtree: true });
                           window.cartObserverAdded = true;
                        }
                      """);
                    }
                  },
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame ?? true) {
                      setState(() {
                        _pageError = true;
                      });
                    }
                    if (_isFirstLoad) {
                      FlutterNativeSplash.remove();
                      _isFirstLoad = false;
                    }
                    pullToRefreshController.endRefreshing();
                    if (_isReloading) {
                      setState(() {
                        _isReloading = false;
                      });
                    }
                  },
                  onReceivedHttpError: (controller, request, errorResponse) {
                    if (request.isForMainFrame ?? true) {
                      if (errorResponse.statusCode != null && errorResponse.statusCode! >= 400) {
                        setState(() {
                          _pageError = true;
                        });
                      }
                    }
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    var uri = navigationAction.request.url;
                    if (uri != null) {
                      if (uri.toString().contains('/b2b/giris')) {
                         await AuthService().logout();
                         if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(deepLinkService: widget.deepLinkService)
                              ),
                              (route) => false,
                            );
                         }
                         return NavigationActionPolicy.CANCEL;
                      }
                      if (["mailto", "tel", "sms", "whatsapp"].contains(uri.scheme)) {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  shouldInterceptAjaxRequest: (controller, ajaxRequest) async {
                    await _jsInterceptorService.handleInterceptedRequest(
                      url: ajaxRequest.url.toString(),
                      method: ajaxRequest.method ?? 'GET',
                      headers: ajaxRequest.headers,
                      body: ajaxRequest.data,
                    );
                    return ajaxRequest;
                  },
                  shouldInterceptFetchRequest: (controller, fetchRequest) async {
                    await _jsInterceptorService.handleInterceptedRequest(
                      url: fetchRequest.url.toString(),
                      method: fetchRequest.method ?? 'GET',
                      headers: fetchRequest.headers,
                      body: fetchRequest.body,
                    );
                    return fetchRequest;
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    // debugPrint("Console: \${consoleMessage.message}");
                  },
                ),
                
                if (_pageError) _buildErrorScreen(),
                
                // Floating Custom Navigation Bar
                if (!_currentUrl.contains('/b2b/giris') && !(_currentUrl.contains('/sepet/detay') && _cartHasItems))
                  Align(
                    alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0, left: 20.0, right: 20.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(
                          height: 65.0,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(210), // Translucent white
                            borderRadius: BorderRadius.circular(30.0),
                            border: Border.all(
                              color: Colors.grey.withAlpha(60), // Glass border
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (!_isHomePage)
                                // Home Button
                                _AnimatedButton(
                                  onPressed: () {
                                    _webViewController?.loadUrl(
                                      urlRequest: URLRequest(url: WebUri("https://bayi.maciterkuafortoptan.com/"))
                                    );
                                  },
                                  icon: const Icon(CupertinoIcons.home, color: Colors.black87, size: 26.0),
                                  tooltip: 'Ana Sayfa',
                                ),


                              // Cart Button
                              _AnimatedButton(
                                onPressed: _toggleCart,
                                icon: const Icon(CupertinoIcons.cart, color: Colors.black87, size: 26.0),
                                tooltip: 'Sepetim',
                              ),
                              
                              // WhatsApp Button
                              _AnimatedButton(
                                onPressed: _openWhatsApp,
                                icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 28.0),
                                tooltip: 'WhatsApp',
                              ),
                              
                              // Scroll to Top Button
                              if (_showScrollToTop)
                                _AnimatedButton(
                                  onPressed: _scrollToTop,
                                  icon: const FaIcon(FontAwesomeIcons.arrowUp, color: Colors.blueAccent, size: 24.0),
                                  tooltip: 'Başa Dön',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _AnimatedButton({required this.icon, required this.onPressed, required this.tooltip});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _controller.reverse(),
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}
