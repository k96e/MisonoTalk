import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class AesUtil {
  static const ivLength = 16;

  static Uint8List deriveKey(String password) {
    return Uint8List.fromList(sha256.convert(utf8.encode(password)).bytes);
  }

  static IV generateRandomIV() {
    final rand = Random.secure();
    final ivBytes = List<int>.generate(ivLength, (_) => rand.nextInt(256));
    return IV(Uint8List.fromList(ivBytes));
  }

  static String encrypt(String plainText, String password) {
    final key = Key(deriveKey(password));
    final iv = generateRandomIV();

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    final combined = iv.bytes + encrypted.bytes;
    return base64Encode(combined);
  }

  static String decrypt(String base64Cipher, String password) {
    final raw = base64Decode(base64Cipher);
    final iv = IV(Uint8List.fromList(raw.sublist(0, ivLength)));
    final ciphertext = Encrypted(Uint8List.fromList(raw.sublist(ivLength)));

    final key = Key(deriveKey(password));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    return encrypter.decrypt(ciphertext, iv: iv);
  }
}
