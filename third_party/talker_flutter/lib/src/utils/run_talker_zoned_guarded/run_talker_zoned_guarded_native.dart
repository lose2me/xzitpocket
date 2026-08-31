import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

Future setupErrorHooks(Talker talker, {bool catchFlutterErrors = true}) async {
  if (catchFlutterErrors) {
    FlutterError.onError = (FlutterErrorDetails details) async {
      talker.handle(details.exception, details.stack);
      if (kDebugMode) {
        // 输出完整报错（含控件的 file:line），便于定位溢出控件
        FlutterError.dumpErrorToConsole(details, forceReport: true);
      }
    };
  }
  PlatformDispatcher.instance.onError = (error, stack) {
    talker.handle(error, stack);
    return true;
  };

  Isolate.current.addErrorListener(RawReceivePort((dynamic pair) async {
    final isolateError = pair as List<dynamic>;
    final error = isolateError.first.toString();
    talker.handle(error);
  }).sendPort);
}
