import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class ControlDeviceKey {
  static final ECDomainParameters _domain = ECDomainParameters('secp256r1');

  final BigInt privateScalar;
  final ECPublicKey publicKey;

  ControlDeviceKey._(this.privateScalar, this.publicKey);

  factory ControlDeviceKey.generate() {
    final random = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List<int>.generate(32, (_) => Random.secure().nextInt(256)),
          ),
        ),
      );
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(_domain), random));
    final pair = generator.generateKeyPair();
    final privateKey = pair.privateKey;
    return ControlDeviceKey._(privateKey.d!, pair.publicKey);
  }

  factory ControlDeviceKey.fromPrivateKey(String encoded) {
    final scalar = _decodeBigInt(_decodeBase64Url(encoded));
    if (scalar <= BigInt.zero || scalar >= _domain.n) {
      throw const FormatException('Invalid P-256 private key');
    }
    return ControlDeviceKey._(scalar, ECPublicKey(_domain.G * scalar, _domain));
  }

  String get privateKeyEncoded =>
      _encodeBase64Url(_encodeBigInt(privateScalar, length: 32));

  String get publicKeyEncoded {
    final point = publicKey.Q!.getEncoded(false);
    const spkiPrefix = <int>[
      0x30,
      0x59,
      0x30,
      0x13,
      0x06,
      0x07,
      0x2a,
      0x86,
      0x48,
      0xce,
      0x3d,
      0x02,
      0x01,
      0x06,
      0x08,
      0x2a,
      0x86,
      0x48,
      0xce,
      0x3d,
      0x03,
      0x01,
      0x07,
      0x03,
      0x42,
      0x00,
    ];
    return _encodeBase64Url(Uint8List.fromList([...spkiPrefix, ...point]));
  }

  String sign(String message) {
    final signer = Signer('SHA-256/DET-ECDSA')
      ..init(
        true,
        PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(privateScalar, _domain)),
      );
    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(message)),
    ) as ECSignature;
    return _encodeBase64Url(_encodeDerSignature(signature.r, signature.s));
  }
}

String controlStudentAlias(String studentId) => sha256
    .convert(utf8.encode('xzitpocket-control|student|$studentId'))
    .toString();

String controlCanonicalLines(Iterable<String> lines) {
  for (final line in lines) {
    if (line.contains('\n') || line.contains('\r') || line.contains('\u0000')) {
      throw const FormatException('Signed fields cannot contain line breaks');
    }
  }
  return lines.join('\n');
}

String controlRandomToken([int length = 24]) {
  final random = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
  return _encodeBase64Url(bytes);
}

Uint8List _encodeDerSignature(BigInt r, BigInt s) {
  final encodedR = _encodeDerInteger(r);
  final encodedS = _encodeDerInteger(s);
  final body = Uint8List.fromList([...encodedR, ...encodedS]);
  return Uint8List.fromList([0x30, body.length, ...body]);
}

Uint8List _encodeDerInteger(BigInt value) {
  var bytes = _encodeBigInt(value);
  if (bytes.isEmpty) bytes = Uint8List.fromList([0]);
  if ((bytes.first & 0x80) != 0) {
    bytes = Uint8List.fromList([0, ...bytes]);
  }
  return Uint8List.fromList([0x02, bytes.length, ...bytes]);
}

Uint8List _encodeBigInt(BigInt value, {int? length}) {
  if (value < BigInt.zero) {
    throw const FormatException('Negative integers are not supported');
  }
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final raw = hex.isEmpty
      ? <int>[]
      : [
          for (var offset = 0; offset < hex.length; offset += 2)
            int.parse(hex.substring(offset, offset + 2), radix: 16),
        ];
  if (length == null) return Uint8List.fromList(raw);
  if (raw.length > length) {
    throw const FormatException('Integer does not fit requested length');
  }
  return Uint8List.fromList([
    ...List<int>.filled(length - raw.length, 0),
    ...raw,
  ]);
}

BigInt _decodeBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

String _encodeBase64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _decodeBase64Url(String value) {
  final padding = '=' * ((4 - value.length % 4) % 4);
  return Uint8List.fromList(base64Url.decode('$value$padding'));
}
