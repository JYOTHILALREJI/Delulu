import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const String baseUrl = 'http://192.168.100.2:3000/api';

  static final http.Client _client = http.Client();

  // Define the timeout duration
  static const Duration _timeout = Duration(seconds: 60);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  static Future<String?> getMeId() async {
    try {
      final res = await getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['user']['id'].toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<http.Response> getNotifications() async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/auth/notifications'), headers: headers).timeout(_timeout);
  }

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

  static Future<void> saveUserData(bool isOnboarded, String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_onboarded', isOnboarded);
    await prefs.setString('display_name', displayName);
  }

  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'is_onboarded': prefs.getBool('is_onboarded') ?? false,
      'display_name': prefs.getString('display_name') ?? '',
    };
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('is_onboarded');
    await prefs.remove('display_name');
  }

  static Future<http.Response> getVersion() async {
    return await _client.get(Uri.parse('$baseUrl/version'));
  }

  static Future<http.Response> register({
    required String email,
    required String password,
    String displayName = '',
  }) {
    return _client.post(
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
    return _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(_timeout);
  }

  static Future<http.Response> getMe() async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/auth/me'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await authHeaders();
    return _client.put(
      Uri.parse('$baseUrl/auth/update-password'),
      headers: headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    ).timeout(_timeout);
  }

  static Future<http.Response> saveProfile(Map<String, dynamic> data) async {
    final headers = await authHeaders();
    return _client.put(
      Uri.parse('$baseUrl/onboarding/profile'),
      headers: headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
  }

  static Future<http.Response> updateOnboardingStep(int step) async {
    final headers = await authHeaders();
    return _client.put(
      Uri.parse('$baseUrl/onboarding/step'),
      headers: headers,
      body: jsonEncode({'step': step}),
    ).timeout(_timeout);
  }

  static Future<http.Response> getDiscoveryFeed({int? ageMin, int? ageMax, double? distanceMiles, int limit = 10, int offset = 0}) async {
    final headers = await authHeaders();
    final queryParams = <String, String>{};
    if (ageMin != null) queryParams['age_min'] = ageMin.toString();
    if (ageMax != null) queryParams['age_max'] = ageMax.toString();
    if (distanceMiles != null) queryParams['distance_miles'] = distanceMiles.toString();
    queryParams['limit'] = limit.toString();
    queryParams['offset'] = offset.toString();

    final uri = Uri.parse('$baseUrl/discovery/feed').replace(queryParameters: queryParams);
    return _client.get(uri, headers: headers).timeout(_timeout);
  }

  static Future<http.Response> getDiscoveryStats() async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/discovery/stats'), headers: headers).timeout(_timeout);
  }

  static Future<http.Response> getPublicProfile(String userId) async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/discovery/profile/$userId'), headers: headers).timeout(_timeout);
  }

  static Future<http.Response> likeUser(String likedUserId) async {
    final headers = await authHeaders();
    return _client
        .post(
          Uri.parse('$baseUrl/likes/like'),
          headers: headers,
          body: jsonEncode({'likedUserId': likedUserId}),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> getLikedProfiles() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/likes/liked'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> getLikedHistory() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/likes/history'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> getReceivedLikes() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/likes/received'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> deleteLike(String likedUserId) async {
    final headers = await authHeaders();
    return _client
        .delete(Uri.parse('$baseUrl/likes/$likedUserId'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> sendConnectionRequest(String receiverId) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/requests/send'),
            headers: headers,
            body: jsonEncode({'receiverId': receiverId}))
        .timeout(_timeout);
  }

  static Future<http.Response> getPendingRequests() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/requests/pending'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> getHistoryRequests() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/requests/history'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> acceptRequest(int requestId) async {
    final headers = await authHeaders();
    return _client
        .put(Uri.parse('$baseUrl/requests/$requestId/accept'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> acceptConnectionRequest(int requestId) => acceptRequest(requestId);

  static Future<http.Response> rejectRequest(int requestId) async {
    final headers = await authHeaders();
    return _client
        .put(Uri.parse('$baseUrl/requests/$requestId/reject'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> rejectConnectionRequest(int requestId) => rejectRequest(requestId);

  static Future<http.Response> getConnections() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/whispers/connections'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> getMessages(int channelId) async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/whispers/messages/$channelId'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> sendMessage(int channelId, String content, {String messageType = 'text', int? duration, int? replyToId}) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/whispers/send'),
            headers: headers,
            body: jsonEncode({
              'channelId': channelId, 
              'content': content,
              'message_type': messageType,
              'duration': duration,
              'reply_to_id': replyToId
            }))
        .timeout(_timeout);
  }

  static Future<http.Response> getUnreadTotal() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/whispers/unread-total'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> markAsRead(int channelId) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/whispers/mark-read/$channelId'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> blockUser(String userId) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/whispers/block'),
            headers: headers, body: jsonEncode({'blockedUserId': userId}))
        .timeout(_timeout);
  }

  static Future<http.Response> reportUser(String userId, String reason) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/whispers/report'),
            headers: headers,
            body: jsonEncode({'reportedUserId': userId, 'reason': reason}))
        .timeout(_timeout);
  }

  static Future<http.Response> unblockUser(String userId) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/whispers/unblock'),
            headers: headers, body: jsonEncode({'blockedUserId': userId}))
        .timeout(_timeout);
  }

  static Future<http.Response> getBlockedUsers() async {
    final headers = await authHeaders();
    return _client
        .get(Uri.parse('$baseUrl/whispers/blocked'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> disconnectUser(String otherUserId) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/requests/disconnect'),
            headers: headers,
            body: jsonEncode({'otherUserId': otherUserId}))
        .timeout(_timeout);
  }

  static Future<http.Response> syncLikes(String userId, int likesCount) async {
    final headers = await authHeaders();
    return _client
        .post(Uri.parse('$baseUrl/discovery/profile/$userId/sync-likes'),
            headers: headers,
            body: jsonEncode({'likesCount': likesCount}))
        .timeout(_timeout);
  }

  // ── Games Endpoints ──
  static Future<http.Response> getGames() async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/games'), headers: headers).timeout(_timeout);
  }

  static Future<http.Response> getGameStatus(int channelId) async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/games/status/$channelId'), headers: headers).timeout(_timeout);
  }

  // ── Leaderboard Endpoint ──
  static Future<http.Response> getLeaderboard() async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/discovery/leaderboard'), headers: headers).timeout(_timeout);
  }

  // ── Subscription Endpoints ──
  static Future<http.Response> getSubscriptionPlans() async {
    final headers = await authHeaders();
    return _client.get(Uri.parse('$baseUrl/premium/plans'), headers: headers).timeout(_timeout);
  }

  static Future<http.Response> verifyPurchase({
    required String userId,
    required String planId,
    required String store,
    String? transactionId,
    String? purchaseToken,
  }) async {
    final headers = await authHeaders();
    return _client.post(
      Uri.parse('$baseUrl/premium/verify'),
      headers: headers,
      body: jsonEncode({
        'userId': userId,
        'planId': planId,
        'store': store,
        'transactionId': transactionId,
        'purchaseToken': purchaseToken,
      }),
    ).timeout(_timeout);
  }

  static Map<String, dynamic> getMeData(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body['user'] ?? {};
    } catch (_) {
      return {};
    }
  }
}