import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionHelper {
  static final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1'); // 32 chars
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  static String encryptMessage(String plainText) {
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return 'E2E:${encrypted.base64}';
    } catch (e) {
      return plainText;
    }
  }

  static String decryptMessage(String encryptedText) {
    if (!encryptedText.startsWith('E2E:')) return encryptedText;
    try {
      final base64 = encryptedText.substring(4);
      final decrypted = _encrypter.decrypt64(base64, iv: _iv);
      return decrypted;
    } catch (e) {
      return '[Decryption Error]';
    }
  }

  static bool isEncrypted(String text) {
    return text.startsWith('E2E:');
  }
}
