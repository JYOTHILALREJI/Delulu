import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';

class EncryptionHelper {
  static final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1'); // 32 chars
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  static String encryptMessage(String plainText) {
    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(plainText, iv: iv);
      
      final data = {
        'em': encrypted.base64,
        'iv': iv.base64,
        'v': 2 // sender_key_version
      };
      
      return 'E2E:${jsonEncode(data)}';
    } catch (e) {
      return plainText;
    }
  }

  static String decryptMessage(String encryptedText) {
    if (!encryptedText.startsWith('E2E:')) return encryptedText;
    try {
      final jsonStr = encryptedText.substring(4);
      final data = jsonDecode(jsonStr);
      
      final iv = encrypt.IV.fromBase64(data['iv']);
      final decrypted = _encrypter.decrypt64(data['em'], iv: iv);
      
      return decrypted;
    } catch (e) {
      return '[Decryption Error]';
    }
  }

  static bool isEncrypted(String text) {
    return text.startsWith('E2E:');
  }
}
