import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/services/resource_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('replacement keeps the old public copy and tracks each file version', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp(
      'resource-download-test',
    );
    addTearDown(() => temp.delete(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const bridge = MethodChannel('live.xuda.xzitpocket/app_bridge');
    messenger.setMockMethodCallHandler(paths, (call) async => temp.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(paths, null);
      messenger.setMockMethodCallHandler(bridge, null);
    });

    final publicFiles = <String, String>{};
    String? opened;
    Completer<void>? pendingExists;
    final checking = Completer<void>();
    messenger.setMockMethodCallHandler(bridge, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      switch (call.method) {
        case 'saveToDownloads':
          final uri = 'content://downloads/${publicFiles.length + 1}';
          final name = publicFiles.isEmpty ? 'paper.pdf' : 'paper (1).pdf';
          publicFiles[uri] = await File(args['path'] as String).readAsString();
          return {'uri': uri, 'name': name};
        case 'mediaExists':
          if (pendingExists != null) {
            checking.complete();
            await pendingExists!.future;
            pendingExists = null;
          }
          return publicFiles.containsKey(args['uri']);
        case 'openDownloaded':
          opened = args['uri'] as String;
          return null;
        default:
          throw StateError('Unexpected method ${call.method}');
      }
    });

    final service = ResourceDownloadService.forTesting(
      adapter: _DocumentAdapter(),
    );
    final old = (await service.download(
      'res-1',
      'https://files.test/original',
      fileName: 'paper.pdf',
      fileVersion: 'original',
    ))!;
    expect(
      await service.isDownloaded('res-1', fileVersion: 'original'),
      isTrue,
    );
    expect(
      await service.isDownloaded('res-1', fileVersion: 'replacement'),
      isFalse,
    );

    // Downloading a new version can finish while the list checks existing files.
    pendingExists = Completer<void>();
    final refresh = service.refresh();
    await checking.future;
    final replacement = (await service.download(
      'res-1',
      'https://files.test/replacement',
      fileName: 'paper.pdf',
      fileVersion: 'replacement',
    ))!;
    pendingExists!.complete();
    await refresh;

    expect(publicFiles[old.uri], 'original');
    expect(publicFiles[replacement.uri], 'replacement');
    expect(replacement.uri, isNot(old.uri));
    expect(
      await service.isDownloaded('res-1', fileVersion: 'replacement'),
      isTrue,
    );
    expect(
      await service.isDownloaded(
        'res-1',
        fileVersion: 'replacement',
        format: 'docx',
      ),
      isFalse,
    );
    await service.open(old);
    expect(opened, old.uri);
    expect(await temp.list().toList(), isEmpty);

    // The saved index survives a restart without dropping the earlier version.
    final reloaded = ResourceDownloadService.forTesting(
      adapter: _DocumentAdapter(),
    );
    expect(
      (await reloaded.recordFor('res-1', fileVersion: 'original'))?.uri,
      old.uri,
    );
    expect(
      (await reloaded.recordFor('res-1', fileVersion: 'replacement'))?.uri,
      replacement.uri,
    );
    publicFiles.remove(old.uri);
    await reloaded.refresh();
    expect(
      await reloaded.isDownloaded('res-1', fileVersion: 'original'),
      isFalse,
    );
    expect(
      await reloaded.isDownloaded('res-1', fileVersion: 'replacement'),
      isTrue,
    );
  });
}

class _DocumentAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final content = options.uri.path.substring(1);
    return ResponseBody.fromString(
      content,
      200,
      headers: {
        Headers.contentLengthHeader: ['${utf8.encode(content).length}'],
        Headers.contentTypeHeader: ['application/pdf'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
