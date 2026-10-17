import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads course PDFs into the app's private storage and opens them with the
/// system PDF viewer. A deterministic file per resource id powers the
/// "已下载/未下载" state across restarts.
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

  Future<File> fileFor(String id) async {
    final dir = await _directory();
    return File(p.join(dir.path, '${_safeId(id)}.pdf'));
  }

  String _safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<bool> isDownloaded(String id) async => (await fileFor(id)).exists();

  Future<File> download(
    String id,
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final file = await fileFor(id);
    final temp = File('${file.path}.part');
    if (await temp.exists()) await temp.delete();
    await _dio.download(url, temp.path, onReceiveProgress: onProgress);
    if (await file.exists()) await file.delete();
    return temp.rename(file.path);
  }

  Future<void> open(File file) => _channel.invokeMethod<void>('openLocalFile', {
    'path': file.path,
    'mime': 'application/pdf',
  });

  /// Opens the system "save as" dialog (SAF) and copies [file] to the chosen
  /// location. Returns false when the user cancels. Requires no permission.
  Future<bool> saveToDocuments(File file, String fileName) async {
    final saved = await _channel.invokeMethod<bool>('saveLocalFile', {
      'path': file.path,
      'fileName': fileName,
    });
    return saved == true;
  }
}
