import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:firebase_base/core/service/crashlytics_reporter.dart';
// Crashlytics has no web implementation and does not even compile there, so
// the SDK-backed reporter is swapped for a no-op stub at compile time.
import 'package:firebase_base/core/service/crashlytics_reporter_stub.dart'
    if (dart.library.io) 'package:firebase_base/core/service/crashlytics_reporter_io.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

/// Crash reporting to Firebase Crashlytics: the application logger, the
/// global error handlers and the collection flag. Not available on the web.
@lazySingleton
final class CrashlyticsService {
  ///
  @visibleForTesting
  CrashlyticsService();

  ///
  static const String _logName = 'Crashlytics Service';

  /// A no-op stub on the web, see the conditional import.
  final CrashlyticsReporter _reporter = createCrashlyticsReporter();

  /// Date in the stack of a report that has none, see [_logError].
  ///
  /// This and [_timeFormat] are pinned to `en_US`: a stamp read by a machine
  /// must not change with the interface language, and the date symbols of
  /// another locale may not be loaded yet when the service is created.
  final _dateFormat = DateFormat('yyyy/MM/dd', 'en_US');

  /// Time stamp of a log line, pinned like [_dateFormat].
  final _timeFormat = DateFormat.Hms('en_US');

  ///
  void prepare() {
    /// There is no Crashlytics on the web: the logger and the error handlers
    /// stay as they are rather than feed a no-op
    if (isWeb) {
      logInfo(info: '$_logName is not supported on web, skipped');
      return;
    }

    logInfoRemote = _logInfo;
    logErrorRemote = _logError;

    FlutterError.onError = _onFatalError;
    PlatformDispatcher.instance.onError = _onError;

    unawaited(_enable());

    logInfo(info: '$_logName prepared');
  }

  /// Undoes a [disable] made on an earlier launch: the SDK persists the flag,
  /// and without this write an application back on Crashlytics would feed a
  /// collector that drops every report.
  Future<void> _enable() async {
    try {
      await _reporter.setCollectionEnabled(isEnabled: true);
    } catch (e) {
      logError(error: '$_logName enabling exception: $e');
    }
  }

  /// Silences Crashlytics for an application that reports crashes elsewhere.
  ///
  /// Skipping [prepare] is not enough: the native SDK starts collecting on
  /// `Firebase.initializeApp` by itself, and native crashes would keep going
  /// to Firebase. Written on every launch rather than once: the SDK persists
  /// the flag, and a [prepare] of an earlier launch may have turned it back
  /// on.
  Future<void> disable() async {
    /// No SDK on the web — nothing to silence
    if (isWeb) {
      logInfo(info: '$_logName is not supported on web, nothing to disable');
      return;
    }

    try {
      await _reporter.setCollectionEnabled(isEnabled: false);
      logInfo(info: '$_logName disabled');
    } catch (e) {
      logError(error: '$_logName disabling exception: $e');
    }
  }

  /// A line of the log attached to the next report, stamped with UTC time.
  void _logInfo({required String information}) => _reporter.log(
    '${_timeFormat.format(DateTime.now().toUtc())} - $information',
  );

  /// A handled error from the application logger.
  Future<void> _logError({required String error, StackTrace? stack}) async {
    if (loggerUserId.isNotEmpty) {
      await _reporter.setCustomKey('User ID', loggerUserId);
    }

    final String date = _dateFormat.format(DateTime.timestamp());

    await _reporter.recordError(
      error,
      // Crashlytics groups issues by stack, and the logger's own stack is the
      // same for every error: a one-frame stack of the date and the text
      // gives each error an issue of its own per day
      stack ?? StackTrace.fromString('#0 $date - $error (app.dart)'),
      reason: error,
      fatal: true,
      printDetails: true,
    );
  }

  /// An error caught by the Flutter framework. The SDK prints it to the
  /// console itself, so replacing the default handler loses nothing.
  void _onFatalError(FlutterErrorDetails errorDetails) =>
      _reporter.recordFlutterFatalError(errorDetails);

  /// An uncaught asynchronous error outside the Flutter framework; `true`
  /// marks it handled.
  bool _onError(Object error, StackTrace stack) {
    /// Returning `true` mutes the engine's own print, and the report is sent
    /// without one, so in debug the error is logged by hand. In debug only:
    /// outside it the logger would report the error a second time
    if (isDebug) {
      logError(error: '$_logName unhandled: $error', stack: stack);
    }

    _reporter.recordError(error, stack, fatal: true);
    return true;
  }
}
