import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://bayi.maciterkuafortoptan.com';
  static const String customUserAgent = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _sessionCookie;
  
  String? get sessionCookie => _sessionCookie;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('auth_cookie');
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      await syncCookiesToWebView(_sessionCookie!);
    }
  }

  Future<void> _saveCookie(String? cookieStr) async {
    final prefs = await SharedPreferences.getInstance();
    if (cookieStr != null && cookieStr.isNotEmpty) {
      await prefs.setString('auth_cookie', cookieStr);
    } else {
      await prefs.remove('auth_cookie');
    }
  }

  // Helper to merge cookies safely without attribute pollution
  String _mergeCookies(String? current, String? incoming) {
    Map<String, String> cookiesMap = {};

    void parseAndAdd(String? str, bool isSetCookieHeader) {
      if (str == null || str.isEmpty) return;

      if (isSetCookieHeader) {
        // Safe split for multiple Set-Cookie headers joined with ', '
        final safeIncoming = str.replaceAll(RegExp(r'(?<!Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s*', caseSensitive: false), '|||');
        final chunks = safeIncoming.split('|||');

        for (var chunk in chunks) {
          final parts = chunk.split(';');
          if (parts.isNotEmpty) {
            final firstPart = parts.first.trim();
            final eqIdx = firstPart.indexOf('=');
            if (eqIdx != -1) {
              final key = firstPart.substring(0, eqIdx).trim();
              final val = firstPart.substring(eqIdx + 1).trim();
              final lowerKey = key.toLowerCase();
              if (key.isNotEmpty && !['expires', 'path', 'domain', 'max-age', 'secure', 'httponly', 'samesite'].contains(lowerKey)) {
                cookiesMap[key] = val;
              }
            }
          }
        }
      } else {
        // Formatted cookie string: "key1=val1; key2=val2"
        final parts = str.split(';');
        for (var p in parts) {
          final trimmed = p.trim();
          final eqIdx = trimmed.indexOf('=');
          if (eqIdx != -1) {
            final key = trimmed.substring(0, eqIdx).trim();
            final val = trimmed.substring(eqIdx + 1).trim();
            final lowerKey = key.toLowerCase();
            if (key.isNotEmpty && !['expires', 'path', 'domain', 'max-age', 'secure', 'httponly', 'samesite'].contains(lowerKey)) {
              cookiesMap[key] = val;
            }
          }
        }
      }
    }

    parseAndAdd(current, false);
    parseAndAdd(incoming, true);

    final merged = cookiesMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
    _saveCookie(merged);
    return merged;
  }

  // Gets the CSRF token and the session cookie needed for requests
  Future<Map<String, String>?> _getCsrfTokenAndCookie(String path) async {
    try {
      final headers = <String, String>{
        'User-Agent': customUserAgent,
      };
      if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
        headers['Cookie'] = _sessionCookie!;
      }
      
      final response = await http.get(Uri.parse('$baseUrl$path'), headers: headers);
      
      if (response.statusCode == 200) {
        final html = response.body;
        final tokenMatch = RegExp(r'name="_token" value="([^"]+)"').firstMatch(html);
        
        String? token;
        if (tokenMatch != null && tokenMatch.groupCount >= 1) {
          token = tokenMatch.group(1);
        }
        
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          _sessionCookie = _mergeCookies(_sessionCookie, cookies);
        }
        
        if (token != null) {
          return {
            'token': token,
            'cookie': _sessionCookie ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint("Error fetching CSRF token: $e");
    }
    return null;
  }

  // Perform Login
  Future<bool> login(String email, String password, {bool rememberMe = true}) async {
    try {
      final initData = await _getCsrfTokenAndCookie('/b2b/giris');
      if (initData == null) return false;

      final token = initData['token']!;
      final requestCookies = initData['cookie']!;

      final request = http.Request('POST', Uri.parse('$baseUrl/b2b/giris-yap'));
      request.headers.addAll({
        'Cookie': requestCookies,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/b2b/giris',
        'User-Agent': customUserAgent,
      });
      request.bodyFields = {
        '_token': token,
        'email': email,
        'password': password,
        if (rememberMe) 'remember': 'on',
      };
      request.followRedirects = false; // Prevent losing Set-Cookie during automatic redirection

      final responseStream = await http.Client().send(request);
      final response = await http.Response.fromStream(responseStream);

      // Extract new session cookies from the POST response
      final newCookies = response.headers['set-cookie'];
      if (newCookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, newCookies);
      }
      
      // Check where the server is trying to redirect us
      final location = response.headers['location'];
      if (response.statusCode == 302 || response.statusCode == 301) {
        // If login fails, it usually redirects back to /b2b/giris
        if (location != null && !location.endsWith('/b2b/giris')) {
          await syncCookiesToWebView(_sessionCookie);
          return true;
        }
      }
      
      // Verification by hitting the login page again as an authenticated user
      final checkRequest = http.Request('GET', Uri.parse('$baseUrl/b2b/giris'));
      checkRequest.headers['Cookie'] = _sessionCookie ?? '';
      checkRequest.headers['User-Agent'] = customUserAgent;
      checkRequest.followRedirects = false;
      
      final checkResponse = await http.Client().send(checkRequest);
      final checkCookies = checkResponse.headers['set-cookie'];
      if (checkCookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, checkCookies);
      }

      if (checkResponse.statusCode == 302 || checkResponse.statusCode == 301) {
        await syncCookiesToWebView(_sessionCookie);
        return true;
      }
      
      // Still returns 200 on login page means we are not logged in.
      return false;
    } catch (e) {
      debugPrint("Login error: $e");
      return false;
    }
  }

  Future<bool> register(Map<String, String> data) async {
    try {
      final initData = await _getCsrfTokenAndCookie('/basvuru');
      if (initData == null) return false;

      final token = initData['token']!;
      final requestCookies = initData['cookie']!;

      data['_token'] = token;

      final request = http.Request('POST', Uri.parse('$baseUrl/basvuru/'));
      request.headers.addAll({
        'Cookie': requestCookies,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/basvuru',
        'User-Agent': customUserAgent,
      });
      request.bodyFields = data;
      request.followRedirects = false;

      final responseStream = await http.Client().send(request);
      final response = await http.Response.fromStream(responseStream);

      final newCookies = response.headers['set-cookie'];
      if (newCookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, newCookies);
      }

      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 200) {
        return true; // B2B registration usually shows a success message
      }
      return false;
    } catch (e) {
      debugPrint("Register error: $e");
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      final initData = await _getCsrfTokenAndCookie('/sifremiunuttum');
      if (initData == null) return false;

      final token = initData['token']!;
      final requestCookies = initData['cookie']!;

      final request = http.Request('POST', Uri.parse('$baseUrl/sifreyenile'));
      request.headers.addAll({
        'Cookie': requestCookies,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/sifremiunuttum',
        'User-Agent': customUserAgent,
      });
      request.bodyFields = {
        '_token': token,
        'email': email,
      };
      request.followRedirects = false;

      final responseStream = await http.Client().send(request);
      final response = await http.Response.fromStream(responseStream);

      final newCookies = response.headers['set-cookie'];
      if (newCookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, newCookies);
      }

      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Forgot password error: $e");
      return false;
    }
  }

  Future<bool> verifyCode(String email, String code) async {
    try {
      final initData = await _getCsrfTokenAndCookie('/sifredogrula');
      if (initData == null) return false;

      final token = initData['token']!;
      final requestCookies = initData['cookie']!;

      final request = http.Request('POST', Uri.parse('$baseUrl/sifredogrula'));
      request.headers.addAll({
        'Cookie': requestCookies,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/sifredogrula',
        'User-Agent': customUserAgent,
      });
      request.bodyFields = {
        '_token': token,
        'email': email,
        'code': code,
      };
      request.followRedirects = false;

      final responseStream = await http.Client().send(request);
      final response = await http.Response.fromStream(responseStream);

      final newCookies = response.headers['set-cookie'];
      if (newCookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, newCookies);
        await syncCookiesToWebView(_sessionCookie);
      }
      
      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Verify code error: $e");
      return false;
    }
  }

  Future<bool> changePassword(String tokenValue, String password, String passwordConfirmation) async {
    try {
      final initData = await _getCsrfTokenAndCookie('/sifredegistir');
      if (initData == null) return false;

      final token = initData['token']!;
      final requestCookies = initData['cookie']!;

      final request = http.Request('POST', Uri.parse('$baseUrl/sifremidegistir'));
      request.headers.addAll({
        'Cookie': requestCookies,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/sifredegistir',
        'User-Agent': customUserAgent,
      });
      request.bodyFields = {
        '_token': token,
        'token': tokenValue,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };
      request.followRedirects = false;

      final responseStream = await http.Client().send(request);
      final response = await http.Response.fromStream(responseStream);

      final newCookies = response.headers['set-cookie'];
      if (newCookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, newCookies);
      }

      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Change password error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    _sessionCookie = null;
    await _saveCookie(null);
    await CookieManager.instance().deleteAllCookies();
  }

  Future<void> syncCookiesToWebView([String? customCookie]) async {
    final cookieHeader = customCookie ?? _sessionCookie;
    if (cookieHeader == null || cookieHeader.isEmpty) return;

    final cookieManager = CookieManager.instance();
    final url = WebUri(baseUrl);
    
    final cookies = cookieHeader.split(';');
    for (var c in cookies) {
      var parts = c.trim().split('=');
      if (parts.length >= 2) {
        var name = parts[0].trim();
        var value = parts.sublist(1).join('=').trim();
        if (['expires', 'path', 'domain', 'httponly', 'secure', 'samesite'].contains(name.toLowerCase())) {
          continue;
        }
        await cookieManager.setCookie(
          url: url,
          name: name,
          value: value,
          domain: "bayi.maciterkuafortoptan.com",
          isSecure: true,
          path: "/",
        );
      }
    }
  }
}
