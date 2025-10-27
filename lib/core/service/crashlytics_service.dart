import 'package:application_base/core/service/logger_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Singleton
final class CrashlyticsService {
  /// Name for logging
  static const String _logName = 'Crashlytics Service';

  /// Common using date format
  final _dateFormat = DateFormat('yyyy/MM/dd', 'en_US');

  /// Common using time format
  final _timeFormat = DateFormat.Hms();

  ///
  void prepare() {
    /// Set up logger functions
    logInfoRemote = _logInfo;
    logErrorRemote = _logError;

    /// Start to handle and pass all crashes and uncaught errors to Crashlytics
    FlutterError.onError = _onFatalError;
    PlatformDispatcher.instance.onError = _onError;

    logInfo(info: '$_logName prepared');
  }

  /// Log event in log trace with log time
  void _logInfo({required String information}) => FirebaseCrashlytics.instance
      .log('${_timeFormat.format(DateTime.now().toUtc())} - $information');

  /// Log error
  Future<void> _logError({required String error, StackTrace? stack}) async {
    /// Add current user ID
    if (loggerUserId.isNotEmpty) {
      await FirebaseCrashlytics.instance.setCustomKey('User ID', loggerUserId);
    }

    /// Event's date - current in UTC
    final String date = _dateFormat.format(DateTime.timestamp());

    /// Finally send error
    await FirebaseCrashlytics.instance.recordError(
      error,
      // For better navigation in Crashlytics make expected errors
      //with date instead of stack trace
      stack ?? StackTrace.fromString('#0 $date - $error (app.dart)'),
      reason: error,
      fatal: true,
      printDetails: true,
    );
  }

  /// Pass all crashes to Crashlytics
  void _onFatalError(FlutterErrorDetails errorDetails) =>
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);

  /// Pass all uncaught asynchronous errors that aren't handled
  /// by the Flutter framework to Crashlytics
  bool _onError(Object error, __) {
    logError(error: error.toString());
    return true;
  }
}
