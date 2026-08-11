import 'package:firebase_base/core/service/crashlytics_reporter.dart';
import 'package:flutter/foundation.dart';

/// Creates the no-op reporter for platforms without Crashlytics (web).
///
/// Free function instead of a constructor: the conditional import in
/// `crashlytics_service.dart` needs an identical entry point in both
/// implementation files.
CrashlyticsReporter createCrashlyticsReporter() => _CrashlyticsReporterStub();

/// Silent no-op: `CrashlyticsService` guards every entry point with a web
/// check, so these methods are unreachable in practice — the class exists to
/// satisfy the compile-time contract, not to handle calls.
final class _CrashlyticsReporterStub implements CrashlyticsReporter {
  ///
  @override
  Future<void> setCollectionEnabled({required bool isEnabled}) async {}

  ///
  @override
  void log(String message) {}

  ///
  @override
  Future<void> setCustomKey(String key, Object value) async {}

  ///
  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
    bool printDetails = false,
  }) async {}

  ///
  @override
  void recordFlutterFatalError(FlutterErrorDetails errorDetails) {}
}
