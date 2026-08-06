import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/deep_link_service.dart';
import 'services/auth_service.dart';
import 'services/tracking_service.dart';
import 'screens/login_screen.dart';
import 'webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await TrackingService.init();

  final deepLinkService = DeepLinkService();
  await deepLinkService.init();

  final authService = AuthService();
  await authService.init();

  // Default System UI mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  
  // If we have a saved session cookie, we can try to start in WebViewScreen.
  // If the session is expired, the server will redirect to /b2b/giris, which will automatically be intercepted 
  // by WebViewScreen to throw us back to LoginScreen.
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getString('auth_cookie') != null;

  runApp(MyApp(deepLinkService: deepLinkService, isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final DeepLinkService deepLinkService;
  final bool isLoggedIn;
  
  const MyApp({super.key, required this.deepLinkService, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maciter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: isLoggedIn 
        ? WebViewScreen(deepLinkService: deepLinkService) 
        : LoginScreen(deepLinkService: deepLinkService),
    );
  }
}
