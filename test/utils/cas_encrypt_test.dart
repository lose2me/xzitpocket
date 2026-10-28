import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/cas_encrypt.dart';

void main() {
  const modulus =
      'c8f1d3a4b5e60789abcdef0123456789abcdef0123456789abcdef0123456789'
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
  const exponent = '10001';

  test('encrypts the reversed password as 16-bit blocks', () {
    // Expected value computed independently from the documented CAS scheme:
    // reverse the password, XOR-free 16-bit little-endian blocks, then RSA.
    expect(
      casEncryptPassword('P@ss中文1', modulus, exponent),
      '91806611dd3253b3332091c014b37cce39f057eb4d2626d75e6d1f833c20e352'
      '2de6100aaed20216971d322c3d4d5aea00f2bcffbf8aadc862108c2452616e1c',
    );
  });

  test('pads short passwords to a full block and stays deterministic', () {
    final first = casEncryptPassword('a', modulus, exponent);
    final second = casEncryptPassword('a', modulus, exponent);
    expect(first, second);
    expect(first.split(' '), hasLength(1));
    expect(first, isNot(casEncryptPassword('b', modulus, exponent)));
  });

  test('splits long passwords into one RSA block per chunk', () {
    final encrypted = casEncryptPassword('x' * 124, modulus, exponent);
    expect(encrypted.split(' '), hasLength(2));
    expect(encrypted.split(' ').every((part) => part.isNotEmpty), isTrue);
  });
}
