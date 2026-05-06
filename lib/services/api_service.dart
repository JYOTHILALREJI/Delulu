import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const String baseUrl = 'http://192.168.100.2:3000/api';

  // Define the timeout duration
  static const Duration _timeout = Duration(seconds: 30);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<http.Response> register({
    required String email,
    required String password,
    String displayName = '',
  }) {
    return http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    ).timeout(_timeout);
  }

  static Future<http.Response> login({
    required String email,
    required String password,
  }) {
    return http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(_timeout);
  }

  static Future<http.Response> getMe() async {
    final headers = await authHeaders();
    return http.get(Uri.parse('$baseUrl/auth/me'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> saveProfile(Map<String, dynamic> data) async {
    final headers = await authHeaders();
    return http.put(
      Uri.parse('$baseUrl/onboarding/profile'),
      headers: headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
  }

  static Future<http.Response> getDiscoveryFeed() async {
    final headers = await authHeaders();
    return http
        .get(Uri.parse('$baseUrl/discovery/feed'), headers: headers)
        .timeout(_timeout);
  }
}