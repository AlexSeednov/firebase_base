import 'package:flutter/foundation.dart';

/// The Crashlytics SDK calls `CrashlyticsService` makes, behind a facade.
///
/// Keeps `firebase_crashlytics` out of the web build, where the plugin does
/// not even compile: the conditional import in `crashlytics_service.dart`
/// picks the SDK-backed implementation or a no-op stub at compile time.
abstract interface class CrashlyticsReporter {
  /// Switches collection on or off; the SDK persists the flag across launches.
  Future<void> setCollectionEnabled({required bool isEnabled});

  /// Adds a line to the log attached to the next report.
  void log(String message);

  /// Attaches a key-value pair to every following report.
  Future<void> setCustomKey(String key, Object value);

  /// Sends a report of a caught error.
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
    bool printDetails = false,
  });

  /// Sends a report of an error caught by the Flutter framework.
  void recordFlutterFatalError(FlutterErrorDetails errorDetails);
}
