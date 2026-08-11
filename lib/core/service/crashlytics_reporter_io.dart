import 'package:firebase_base/core/service/crashlytics_reporter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Creates the real SDK-backed reporter.
///
/// Free function instead of a constructor: the conditional import in
/// `crashlytics_service.dart` needs an identical entry point in both
/// implementation files.
CrashlyticsReporter createCrashlyticsReporter() => _CrashlyticsReporterIO();

/// Forwards every call to the native Crashlytics SDK.
final class _CrashlyticsReporterIO implements CrashlyticsReporter {
  ///
  @override
  Future<void> setCollectionEnabled({required bool isEnabled}) =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(isEnabled);

  ///
  @override
  void log(String message) => FirebaseCrashlytics.instance.log(message);

  ///
  @override
  Future<void> setCustomKey(String key, Object value) =>
      FirebaseCrashlytics.instance.setCustomKey(key, value);

  ///
  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
    bool printDetails = false,
  }) => FirebaseCrashlytics.instance.recordError(
    error,
    stack,
    reason: reason,
    fatal: fatal,
    printDetails: printDetails,
  );

  ///
  @override
  void recordFlutterFatalError(FlutterErrorDetails errorDetails) =>
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
}
