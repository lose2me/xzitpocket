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

  bool get isForced => upgradeType == 3;

  String get upgradeLabel {
    return switch (upgradeType) {
      1 => '推荐更新',
      2 => '推荐更新',
      3 => '强制更新',
      _ => '发现新版本',
    };
  }
}
