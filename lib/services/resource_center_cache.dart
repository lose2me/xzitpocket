import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/resource_center.dart';

/// Serialized resource-centre course list. [version] is the server revision the
/// list was fetched for, so a matching `/config/versions` response can skip the
/// request entirely.
class ResourceCenterSnapshot {
  final String version;
  final List<ResourceCourse> courses;

  const ResourceCenterSnapshot({required this.version, required this.courses});

  factory ResourceCenterSnapshot.fromJson(Map<String, dynamic> json) =>
      ResourceCenterSnapshot(
        version: json['version']?.toString() ?? '',
        courses: [
          for (final item in (json['courses'] as List? ?? const []))
            if (item is Map)
              ResourceCourse.fromJson({...item.cast<String, dynamic>()}),
        ],
      );

  Map<String, dynamic> toJson() => {
    'version': version,
    'courses': [for (final course in courses) course.toJson()],
  };

  String encode() => jsonEncode(toJson());

  static ResourceCenterSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ResourceCenterSnapshot.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}

/// Serialized course detail. [version] must equal the course's server version
/// before the cached rows can be shown without a request.
class ResourceCourseSnapshot {
  final String version;
  final List<CourseResourceItem> resources;
  final List<CourseTextbookItem> textbooks;

  const ResourceCourseSnapshot({
    required this.version,
    required this.resources,
    required this.textbooks,
  });

  factory ResourceCourseSnapshot.fromJson(Map<String, dynamic> json) =>
      ResourceCourseSnapshot(
        version: json['version']?.toString() ?? '',
        resources: [
          for (final item in (json['resources'] as List? ?? const []))
            if (item is Map)
              CourseResourceItem.fromJson({...item.cast<String, dynamic>()}),
        ],
        textbooks: [
          for (final item in (json['textbooks'] as List? ?? const []))
            if (item is Map)
              CourseTextbookItem.fromJson({...item.cast<String, dynamic>()}),
        ],
      );

  Map<String, dynamic> toJson() => {
    'version': version,
    'resources': [for (final item in resources) item.toJson()],
    'textbooks': [for (final item in textbooks) item.toJson()],
  };

  String encode() => jsonEncode(toJson());

  static ResourceCourseSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ResourceCourseSnapshot.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}

/// Stores course covers in the app's private storage so the resource centre
/// keeps its cover art offline and never depends on an expired CDN URL.
class ResourceCoverCache {
  ResourceCoverCache._();

  static final ResourceCoverCache instance = ResourceCoverCache._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<Directory> _directory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'resource_covers'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _safeCode(String code) =>
      code.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  String _hash(String value) =>
      sha1.convert(utf8.encode(value)).toString().substring(0, 12);

  /// A cover version change produces a new file name, so a replaced cover is
  /// never served from the old cache.
  Future<File> _fileFor(ResourceCourse course) async {
    final dir = await _directory();
    return File(
      p.join(
        dir.path,
        '${_safeCode(course.code)}-${_hash(course.coverVersion)}.webp',
      ),
    );
  }

  /// Returns the local cover path for a course when it is already cached.
  Future<String?> displayPath(ResourceCourse course) async {
    if (course.coverUrl.trim().isEmpty) return null;
    final file = await _fileFor(course);
    return await file.exists() ? file.path : null;
  }

  Future<Map<String, String>> displayPaths(
    Iterable<ResourceCourse> courses,
  ) async {
    final result = <String, String>{};
    for (final course in courses) {
      final path = await displayPath(course);
      if (path != null) result[course.code] = path;
    }
    return result;
  }

  /// Downloads a missing cover. Returns null (and leaves the network URL as the
  /// page's fallback) when the URL expired or the download failed.
  Future<String?> ensure(ResourceCourse course) async {
    final url = course.coverUrl.trim();
    if (url.isEmpty) return null;
    final file = await _fileFor(course);
    if (await file.exists()) return file.path;
    final temp = File('${file.path}.part');
    try {
      await _dio.download(url, temp.path);
      await temp.rename(file.path);
      return file.path;
    } catch (_) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
      return null;
    }
  }

  /// Removes every cached cover when resource caches are explicitly cleared.
  Future<void> clear() async {
    final dir = await _directory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Drops covers for removed courses and for superseded cover versions.
  Future<void> prune(Iterable<ResourceCourse> courses) async {
    final keep = <String>{};
    for (final course in courses) {
      if (course.coverUrl.trim().isEmpty) continue;
      keep.add((await _fileFor(course)).path);
    }
    final dir = await _directory();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith('.webp') && !name.endsWith('.part')) continue;
      if (!keep.contains(entity.path)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}
