import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class AesUtil {
  static Map<String, Uint8List> generateKeyAndIv(String password) {
    final key = sha256.convert(utf8.encode(password)).bytes;

    final iv = md5.convert(utf8.encode(password)).bytes;

    return {
      'key': Uint8List.fromList(key),
      'iv': Uint8List.fromList(iv),
    };
  }

  static String encrypt(String plainText, String password) {
    final keyIv = generateKeyAndIv(password);
    final key = Key(keyIv['key']!);
    final iv = IV(keyIv['iv']!);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  static String decrypt(String encryptedText, String password) {
    final keyIv = generateKeyAndIv(password);
    final key = Key(keyIv['key']!);
    final iv = IV(keyIv['iv']!);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
    return decrypted;
  }
}
