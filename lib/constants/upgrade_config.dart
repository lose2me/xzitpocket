class UpgradeConfig {
  UpgradeConfig._();

  static const accessKey = String.fromEnvironment('UPGRADELINK_ACCESS_KEY');
  static const secretKey = String.fromEnvironment('UPGRADELINK_SECRET_KEY');
  static const urlKey = String.fromEnvironment('UPGRADELINK_URL_KEY');
  static const devModelKey = String.fromEnvironment(
    'UPGRADELINK_DEV_MODEL_KEY',
  );
  static const devKey = String.fromEnvironment('UPGRADELINK_DEV_KEY');
  static const endpoint = String.fromEnvironment(
    'UPGRADELINK_ENDPOINT',
    defaultValue: 'api.upgrade.toolsetlink.com',
  );
  static const protocol = String.fromEnvironment(
    'UPGRADELINK_PROTOCOL',
    defaultValue: 'https',
  );

  static bool get isConfigured {
    return accessKey.isNotEmpty && secretKey.isNotEmpty && urlKey.isNotEmpty;
  }
}
