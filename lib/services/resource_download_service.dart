import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One downloaded document. [uri] is the MediaStore content URI (or the
/// scanner URI on Android 9 and below) and [name] is the file name shown in
/// the Downloads folder.
class DownloadedResource {
  const DownloadedResource({required this.uri, required this.name});

  final String uri;
  final String name;

  Map<String, dynamic> toJson() => {'uri': uri, 'name': name};

  static DownloadedResource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final uri = raw['uri'];
    if (uri is! String || uri.isEmpty) return null;
    final name = raw['name'];
    return DownloadedResource(
      uri: uri,
      name: name is String && name.isNotEmpty ? name : 'document.pdf',
    );
  }
}

/// Downloads course documents straight into the public Downloads folder and
/// opens them through their content URI. The public copy is the only stored
/// copy; a small index in SharedPreferences maps resource id + format to the
/// URI so the "已下载" state survives restarts. Entries whose file the user
/// deleted or renamed away are dropped on [refresh].
class ResourceDownloadService {
  ResourceDownloadService._();

  static final ResourceDownloadService instance = ResourceDownloadService._();

  static const _channel = MethodChannel('live.xuda.xzitpocket/app_bridge');
  static const _prefsKey = 'resource_downloads_v1';
  static const _migratedKey = 'resource_downloads_migrated_v1';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  final Map<String, DownloadedResource> _index = {};
  bool _loaded = false;

  String _key(String id, String format) =>
      '${id.trim()}|${_safeFormat(format)}';

  String _safeFormat(String format) => switch (format.toLowerCase()) {
    'docx' => 'docx',
    'doc' => 'doc',
    _ => 'pdf',
  };

  String _mimeFor(String format) => switch (_safeFormat(format)) {
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'doc' => 'application/msword',
    _ => 'application/pdf',
  };

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _index.clear();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final record = DownloadedResource.fromJson(value);
            if (record != null) _index[key.toString()] = record;
          });
        }
      } catch (_) {
        // A corrupt index only loses the downloaded markers; files stay.
      }
    }
    _loaded = true;
  }

  /// Earlier versions cached documents in the private storage; that copy is
  /// no longer used, so remove it once to reclaim the space.
  Future<void> _cleanupLegacyCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'resource_center'));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    await prefs.setBool(_migratedKey, true);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_index.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  /// Drops index entries whose file no longer exists in MediaStore, so a file
  /// deleted from the Files app shows as 未下载 again. Call before reading the
  /// downloaded state for a list.
  Future<void> refresh() async {
    await _cleanupLegacyCache();
    await _ensureLoaded();
    if (_index.isEmpty) return;
    final missing = <String>[];
    for (final entry in _index.entries) {
      bool exists;
      try {
        exists =
            await _channel.invokeMethod<bool>('mediaExists', {
              'uri': entry.value.uri,
            }) ==
            true;
      } on MissingPluginException {
        exists = true;
      } on PlatformException {
        exists = true;
      }
      if (!exists) missing.add(entry.key);
    }
    if (missing.isEmpty) return;
    for (final key in missing) {
      _index.remove(key);
    }
    await _persist();
  }

  Future<DownloadedResource?> recordFor(
    String id, {
    String format = 'pdf',
  }) async {
    await _ensureLoaded();
    return _index[_key(id, format)];
  }

  Future<bool> isDownloaded(String id, {String format = 'pdf'}) async {
    await _ensureLoaded();
    return _index.containsKey(_key(id, format));
  }

  /// Streams [url] into a temporary file, hands it to the platform so it lands
  /// in the Downloads folder, and records the resulting content URI.
  Future<DownloadedResource?> download(
    String id,
    String url, {
    required String fileName,
    String format = 'pdf',
    void Function(int received, int total)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final temp = File(
      p.join(
        tempDir.path,
        'resource_${DateTime.now().microsecondsSinceEpoch}.${_safeFormat(format)}',
      ),
    );
    try {
      await _dio.download(url, temp.path, onReceiveProgress: onProgress);
      final saved = await _channel.invokeMapMethod<String, dynamic>(
        'saveToDownloads',
        {
          'path': temp.path,
          'fileName': fileName,
          'mime': _mimeFor(format),
        },
      );
      final record = DownloadedResource.fromJson(saved);
      if (record == null) return null;
      await _ensureLoaded();
      _index[_key(id, format)] = record;
      await _persist();
      return record;
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  /// Opens a downloaded document with the system viewer.
  Future<void> open(
    DownloadedResource record, {
    String format = 'pdf',
  }) => _channel.invokeMethod<void>('openDownloaded', {
    'uri': record.uri,
    'mime': _mimeFor(format),
  });
}
