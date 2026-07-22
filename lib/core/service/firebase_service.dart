import 'package:application_base/core/service/logger_service.dart';
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
  Future<bool> prepare({FirebaseOptions? options}) async {
    try {
      await Firebase.initializeApp(options: options);
    } catch (e) {
      logError(error: '$_logName initialization exception: $e');
      return false;
    }

    /// Need to do here to start logger as soon as possible.
    /// Only after a successful initialization - Crashlytics has no instance
    /// to bind its handlers to otherwise.
    getIt<CrashlyticsService>().prepare();

    logInfo(info: '$_logName prepared');
    return true;
  }
}
