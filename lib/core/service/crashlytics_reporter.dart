import 'package:flutter/foundation.dart';

/// Thin facade over the Crashlytics SDK calls used by `CrashlyticsService`.
///
/// Exists only to keep the `firebase_crashlytics` import out of the web
/// compilation: the plugin has no web implementation and does not even
/// compile there. The io implementation forwards to the SDK, the stub is a
/// silent no-op. The concrete class is chosen at compile time via conditional
/// import in `crashlytics_service.dart`.
abstract interface class CrashlyticsReporter {
  /// Turn the SDK data collection on or off (persisted between launches).
  Future<void> setCollectionEnabled({required bool isEnabled});

  /// Add a message to the crash report log trace.
  void log(String message);

  /// Attach a custom key-value pair to every following report.
  Future<void> setCustomKey(String key, Object value);

  /// Send a recorded (caught) error report.
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
    bool printDetails = false,
  });

  /// Send an uncaught Flutter framework error report.
  void recordFlutterFatalError(FlutterErrorDetails errorDetails);
}
