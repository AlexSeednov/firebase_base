import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:firebase_base/core/service/crashlytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:injectable/injectable.dart';

/// Singleton
@lazySingleton
final class FirebaseService {
  /// Name for logging
  static const String _logName = 'Firebase Service';

  ///
  Future<void> prepare({FirebaseOptions? options}) async {
    await Firebase.initializeApp(options: options);

    /// Need to do here to start logger as soon as possible
    getIt<CrashlyticsService>().prepare();

    logInfo(info: '$_logName prepared');
  }
}
