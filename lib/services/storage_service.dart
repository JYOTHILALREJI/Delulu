import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StorageService {
  static Future<String> uploadFile(File file) async {
    final uri = Uri.parse('${dotenv.env['API_BASE_URL']}/api/upload');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final url = Uri.parse(responseBody).queryParameters['url'];
      return url ?? '';
    }
    throw Exception('Failed to upload file');
  }

  static Future<String> uploadFromBytes(List<int> bytes, String fileName) async {
    final uri = Uri.parse('${dotenv.env['API_BASE_URL']}/api/upload');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final response = await request.send();
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final url = Uri.parse(responseBody).queryParameters['url'];
      return url ?? '';
    }
    throw Exception('Failed to upload file');
  }
}