import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:firebase_base/core/service/crashlytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

///
@lazySingleton
final class FirebaseService {
  ///
  @visibleForTesting
  FirebaseService();

  /// Name for logging
  static const String _logName = 'Firebase Service';

  /// Reports a failure instead of throwing: a missing or malformed native
  /// configuration must cost the application its telemetry, not its launch.
  ///
  /// [isCrashlyticsEnabled] `false` leaves messaging and the rest of Firebase
  /// intact while handing crash reporting over to another tool — the two are
  /// independent, and an app reporting to both would pay twice for the same
  /// crash and see it split across dashboards.
  Future<bool> prepare({
    FirebaseOptions? options,
    bool isCrashlyticsEnabled = true,
  }) async {
    /// On web there is no native config file to read the options from, so
    /// without explicit [options] initialization is guaranteed to fail - skip
    /// cleanly instead of paying for the exception
    if (isWeb && options == null) {
      logInfo(
        info: '$_logName: web requires explicit FirebaseOptions, skipped',
      );
      return false;
    }

    try {
      await Firebase.initializeApp(options: options);
    } catch (e) {
      logError(error: '$_logName initialization exception: $e');
      return false;
    }

    /// Need to do here to start logger as soon as possible.
    /// Only after a successful initialization - Crashlytics has no instance
    /// to bind its handlers to otherwise.
    final CrashlyticsService crashlytics = getIt<CrashlyticsService>();
    if (isCrashlyticsEnabled) {
      crashlytics.prepare();
    } else {
      await crashlytics.disable();
    }

    logInfo(info: '$_logName prepared');
    return true;
  }
}
