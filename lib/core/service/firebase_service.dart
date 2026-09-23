import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:firebase_base/core/service/crashlytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

/// Firebase core start-up, which also decides the fate of Crashlytics.
@lazySingleton
final class FirebaseService {
  ///
  @visibleForTesting
  FirebaseService();

  ///
  static const String _logName = 'Firebase Service';

  /// Returns `false` instead of throwing: a missing or malformed native
  /// configuration costs the application its telemetry, not its launch.
  ///
  /// [isCrashlyticsEnabled] `false` keeps messaging and the rest of Firebase
  /// but silences Crashlytics, for an application that reports crashes
  /// elsewhere — otherwise it pays twice for every crash and sees it split
  /// across two dashboards.
  Future<bool> prepare({
    FirebaseOptions? options,
    bool isCrashlyticsEnabled = true,
  }) async {
    /// The web has no native config file to read the options from: without
    /// explicit [options] the initialization is bound to fail, so it is
    /// skipped rather than paid for with an exception
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

    /// Right away, so the logger reports to Crashlytics from the start — but
    /// only after a successful initialization: before it Crashlytics has no
    /// instance to bind its handlers to
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
