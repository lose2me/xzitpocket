import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide Talker instance used by the UI, services, and Dio.
///
/// Request and response data are intentionally logged in full. This is a
/// local diagnostic mode and must not be enabled when logs can leave the
/// device.
final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: true,
    useHistory: true,
    useConsoleLogs: true,
    maxHistoryItems: 5000,
  ),
);

final talkerDioLogger = TalkerDioLogger(
  talker: talker,
  settings: const TalkerDioLoggerSettings(
    enabled: true,
    logLevel: LogLevel.debug,
    printRequestData: true,
    printRequestHeaders: true,
    printRequestExtra: true,
    printResponseData: true,
    printResponseHeaders: true,
    printResponseMessage: true,
    printResponseRedirects: true,
    printResponseTime: true,
    printErrorData: true,
    printErrorHeaders: true,
    printErrorMessage: true,
    hiddenHeaders: <String>{},
  ),
);
