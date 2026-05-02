import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CallService {
  static Future<String> getAgoraToken(String channelName, int uid) async {
    final supabaseFunctionsUrl = dotenv.env['SUPABASE_FUNCTIONS_URL']!;
    final response = await http.post(
      Uri.parse('$supabaseFunctionsUrl/agora-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channelName': channelName, 'uid': uid}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['token'];
    }
    throw Exception('Failed to get Agora token');
  }
}