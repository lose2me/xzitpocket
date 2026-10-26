import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads course documents into the app's private storage and opens them
/// with the matching system viewer. A deterministic file per resource id and
/// format powers the "已下载/未下载" state across restarts.
class ResourceDownloadService {
  ResourceDownloadService._();

  static final ResourceDownloadService instance = ResourceDownloadService._();

  static const _channel = MethodChannel('live.xuda.xzitpocket/app_bridge');

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  Future<Directory> _directory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'resource_center'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> fileFor(String id, {String format = 'pdf'}) async {
    final dir = await _directory();
    return File(p.join(dir.path, '${_safeId(id)}.${_safeFormat(format)}'));
  }

  String _safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

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

  Future<bool> isDownloaded(String id, {String format = 'pdf'}) async =>
      (await fileFor(id, format: format)).exists();

  Future<File> download(
    String id,
    String url, {
    String format = 'pdf',
    void Function(int received, int total)? onProgress,
  }) async {
    final file = await fileFor(id, format: format);
    final temp = File('${file.path}.part');
    if (await temp.exists()) await temp.delete();
    await _dio.download(url, temp.path, onReceiveProgress: onProgress);
    if (await file.exists()) await file.delete();
    return temp.rename(file.path);
  }

  Future<void> open(File file, {String format = 'pdf'}) =>
      _channel.invokeMethod<void>('openLocalFile', {
        'path': file.path,
        'mime': _mimeFor(format),
      });

  /// Copies [file] into the system Downloads folder without a picker and
  /// returns the display path (for example `Download/试卷.pdf`). Android 10+
  /// goes through MediaStore, older versions write the public directory after
  /// asking for the storage permission.
  Future<String?> saveToDownloads(
    File file,
    String fileName, {
    String format = 'pdf',
  }) async {
    final saved = await _channel.invokeMethod<String>('saveToDownloads', {
      'path': file.path,
      'fileName': fileName,
      'mime': _mimeFor(format),
    });
    if (saved == null || saved.isEmpty) return null;
    return saved;
  }
}
