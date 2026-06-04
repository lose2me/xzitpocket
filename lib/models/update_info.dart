class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String releaseNotes;
  final int upgradeType;

  const UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.upgradeType,
  });

  bool get isForced => upgradeType == 1;

  String get upgradeLabel {
    return switch (upgradeType) {
      1 => '强制更新',
      2 => '推荐更新',
      3 => '可选更新',
      _ => '发现新版本',
    };
  }
}
