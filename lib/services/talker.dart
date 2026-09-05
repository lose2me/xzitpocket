import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide Talker instance used by the UI, services, and Dio.
///
/// Request and response data are intentionally available in the local
/// diagnostic view. When Talker is enabled, error-level records are also
/// sent to Control after sensitive fields are redacted.
final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: false,
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
