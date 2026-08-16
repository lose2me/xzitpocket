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

/// Enables or disables both Talker's history/console output and Dio request
/// logging. The logger settings are immutable, so rebuild them while
/// preserving the full-payload diagnostics configuration.
void setTalkerLoggingEnabled(bool enabled) {
  talker.settings.enabled = enabled;
  final current = talkerDioLogger.settings;
  talkerDioLogger.settings = TalkerDioLoggerSettings(
    enabled: enabled,
    logLevel: current.logLevel,
    printRequestData: current.printRequestData,
    printRequestHeaders: current.printRequestHeaders,
    printRequestExtra: current.printRequestExtra,
    printResponseData: current.printResponseData,
    printResponseHeaders: current.printResponseHeaders,
    printResponseMessage: current.printResponseMessage,
    printResponseRedirects: current.printResponseRedirects,
    printResponseTime: current.printResponseTime,
    printErrorData: current.printErrorData,
    printErrorHeaders: current.printErrorHeaders,
    printErrorMessage: current.printErrorMessage,
    hiddenHeaders: current.hiddenHeaders,
    jsonFormatter: current.jsonFormatter,
    responseDataConverter: current.responseDataConverter,
    requestPen: current.requestPen,
    responsePen: current.responsePen,
    errorPen: current.errorPen,
    requestFilter: current.requestFilter,
    responseFilter: current.responseFilter,
    errorFilter: current.errorFilter,
  );
}
