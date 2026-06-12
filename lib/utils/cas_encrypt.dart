String casEncryptPassword(String password, String modulusHex, String exponentHex) {
  return _rsaEncrypt(
    String.fromCharCodes(password.runes.toList().reversed),
    exponentHex,
    modulusHex,
  );
}

String _rsaEncrypt(String message, String exponentHex, String modulusHex) {
  final e = BigInt.parse(exponentHex, radix: 16);
  final n = BigInt.parse(modulusHex, radix: 16);
  final nDigits = (n.bitLength + 15) ~/ 16;
  final chunkSize = 2 * (nDigits - 1);

  final msgBytes = message.codeUnits.toList();
  while (msgBytes.length % chunkSize != 0) {
    msgBytes.add(0);
  }

  final parts = <String>[];
  for (var i = 0; i < msgBytes.length; i += chunkSize) {
    var block = BigInt.zero;
    for (var j = 0; j < chunkSize; j += 2) {
      final low = msgBytes[i + j];
      final high = (i + j + 1 < msgBytes.length) ? msgBytes[i + j + 1] : 0;
      final word = BigInt.from(low | (high << 8));
      block |= word << (16 * (j ~/ 2));
    }
    parts.add(block.modPow(e, n).toRadixString(16));
  }
  return parts.join(' ');
}
