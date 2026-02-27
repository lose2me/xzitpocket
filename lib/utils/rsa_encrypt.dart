import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Encrypts [password] using RSA PKCS1 v1.5 with base64-encoded
/// [modulus] and [exponent] (matching the Python `rsa.encrypt` behavior).
String encryptPassword(String password, String modulus, String exponent) {
  final rsaN = _base64ToBigInt(modulus);
  final rsaE = _base64ToBigInt(exponent);

  final publicKey = RSAPublicKey(rsaN, rsaE);

  final secureRandom = _getSecureRandom();

  final encryptor = PKCS1Encoding(RSAEngine())
    ..init(
      true,
      ParametersWithRandom(
        PublicKeyParameter<RSAPublicKey>(publicKey),
        secureRandom,
      ),
    );

  final input = Uint8List.fromList(utf8.encode(password));
  final encrypted = encryptor.process(input);

  return base64.encode(encrypted);
}

BigInt _base64ToBigInt(String b64) {
  final bytes = base64.decode(b64);
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return BigInt.parse(hex, radix: 16);
}

SecureRandom _getSecureRandom() {
  final random = Random.secure();
  final seeds = List<int>.generate(32, (_) => random.nextInt(256));
  final secureRandom = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(seeds)));
  return secureRandom;
}
