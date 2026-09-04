import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:xzitpocket/services/control_crypto.dart';
import 'package:xzitpocket/services/control_service.dart';

void main() {
  test('P-256 key round trips and emits Go-compatible signatures', () {
    final key = ControlDeviceKey.generate();
    final restored = ControlDeviceKey.fromPrivateKey(key.privateKeyEncoded);
    const message = 'xzitpocket-control-device\ninstallation\npublic-key';
    final signature = base64Url.decode(_withPadding(restored.sign(message)));
    final publicKey = base64Url.decode(_withPadding(restored.publicKeyEncoded));

    expect(restored.publicKeyEncoded, key.publicKeyEncoded);
    expect(publicKey.sublist(0, 3), [0x30, 0x59, 0x30]);

    final values = _decodeDerSignature(signature);
    final domain = ECDomainParameters('secp256r1');
    final point = domain.curve.decodePoint(publicKey.sublist(26));
    final verifier = Signer(
      'SHA-256/ECDSA',
    )..init(false, PublicKeyParameter<ECPublicKey>(ECPublicKey(point, domain)));
    expect(
      verifier.verifySignature(
        Uint8List.fromList(utf8.encode(message)),
        ECSignature(values.$1, values.$2),
      ),
      isTrue,
    );
  });

  test('student alias follows the control contract', () {
    expect(
      controlStudentAlias('20260001'),
      'aeb685f98fd431f9e88b971b7f1a6444be74df5f5693c8f08b4101ecf7dc0da8',
    );
  });

  test('version comparison uses numeric segments', () {
    expect(isControlVersionNewer('2.0.4', '2.0.3'), isTrue);
    expect(isControlVersionNewer('2.0.3', '2.0.3'), isFalse);
    expect(isControlVersionNewer('2.0.3', '2.0.10'), isFalse);
    expect(isControlVersionNewer('2.1.0+8', '2.0.9+99'), isTrue);
  });
}

String _withPadding(String value) =>
    '$value${'=' * ((4 - value.length % 4) % 4)}';

(BigInt, BigInt) _decodeDerSignature(List<int> bytes) {
  expect(bytes[0], 0x30);
  var offset = 2;
  expect(bytes[offset++], 0x02);
  final rLength = bytes[offset++];
  final r = _decodeBigInt(bytes.sublist(offset, offset + rLength));
  offset += rLength;
  expect(bytes[offset++], 0x02);
  final sLength = bytes[offset++];
  final s = _decodeBigInt(bytes.sublist(offset, offset + sLength));
  return (r, s);
}

BigInt _decodeBigInt(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}
