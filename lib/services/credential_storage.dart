import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _savedPasswordKey = 'saved_password';

class CredentialStorage {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static Future<String?> getSavedPassword() =>
      _secureStorage.read(key: _savedPasswordKey);

  static Future<void> setSavedPassword(String pwd) =>
      _secureStorage.write(key: _savedPasswordKey, value: pwd);

  static Future<void> clearPassword() =>
      _secureStorage.delete(key: _savedPasswordKey);
}
