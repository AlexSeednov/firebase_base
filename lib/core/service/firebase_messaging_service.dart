import 'dart:async';

import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:firebase_base/core/entity/push_entity.dart';
import 'package:firebase_base/core/service/local_notifications_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rxdart/rxdart.dart';

/// Singleton
///
/// Messages have different behaviour depends on application state and OS.
/// Application state can be:
///
/// * **Foreground** - When the application is open, in view and in use
///
/// * **Background** - When the application is open, but in the background
/// (minimized). This typically occurs when the user has pressed the "home"
/// button on the device, has switched to another app using the app switcher,
/// or has the application open in a different tab (web).
///
/// * **Terminated** - When the device is locked or the application
/// is not running
///
/// In **Foreground** pushes will be shown after some preparations:
///
/// * On **Android**, you must create a "High Priority" notification channel,
/// but sometimes it doesn't work..
/// So it's better to use local notifications via special package
///
/// * On **iOS**, you can update the presentation options for the application
/// via FirebaseMessaging -> setForegroundNotificationPresentationOptions
///
/// Details in [Firebase docs](https://firebase.google.com/docs/cloud-messaging/flutter/receive)
///
/// Sheme with common information [here](https://user-images.githubusercontent.com/40064496/197368144-7bfcee7e-644a-4bdc-80f1-b4d38c2eaaff.png)
final class FirebaseMessagingService with LoggingMixin {
  /// Name for logging
  @override
  final String logName = 'Firebase messaging';

  /// Firebase unique token for current device
  String _token = '';

  /// Get Firebase unique token for current device
  String get token => _token;

  /// APNs unique token - only for iOS
  String? _apnsToken;

  /// Get APNs unique token - only for iOS
  String? get apnsToken => _apnsToken;

  /// Main instance for messaging via Firebase
  late FirebaseMessaging? _messaging;

  /// Stream for listening route from push
  final pushSubject = BehaviorSubject<Map<String, dynamic>>();

  ///
  void Function(String)? onTokenChanged;

  /// Initialization of all necessary data
  Future<bool> prepare({required String name}) async {
    try {
      /// Init messaging instance
      _messaging = FirebaseMessaging.instance;

      /// Platform-specific castomization
      if (isIOS) {
        /// Activate foreground messaging for iOS
        await _messaging!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (isAndroid) {
        /// Special behaviour for Android only - need to show local
        /// messages via special package in foreground
        await getIt<LocalNotificationsService>().prepare(
          handleMessage: _handleForegroundMessage,
          name: name,
        );
        FirebaseMessaging.onMessage.listen(_onForegroundListen);
      }

      ///
      final bool result = await _getToken(lastTry: false);
      if (!result) {
        /// Try one more time after small delay
        logNamedInfo(info: 'Try to get tokens one more time');
        await Future<void>.delayed(const Duration(seconds: 1));
        await _getToken(lastTry: true);
      }

      /// Any time the token refreshes, need to get it
      _messaging!.onTokenRefresh.listen(_tokenChanged);

      ///
      unawaited(_onInitializationHandle());
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedListen);
    } catch (e) {
      logNamedError(error: 'initialization exception: $e');
      return false;
    }

    /// Success
    logNamedInfo(info: 'initialized');
    return true;
  }

  ///
  void dispose() {
    pushSubject.close();
  }

  /// Log as errors only if [lastTry] is true, log as information otherwise
  Future<bool> _getToken({required bool lastTry}) async {
    try {
      if (isIOS) {
        /// APNs token is available only on iOS
        _apnsToken = await _messaging!.getAPNSToken();
        if (_apnsToken == null) {
          /// Do not log it as error to provide better logs
          logNamedInfo(info: 'apnsToken is null');
        } else {
          logNamedInfo(info: 'apnsToken ready');
        }
      }

      /// Get unique firebase token
      _token = await _messaging!.getToken() ?? '';
      if (_token.isEmpty) {
        if (lastTry) {
          logNamedError(error: 'FCM token is empty');
        } else {
          logNamedInfo(info: 'FCM token is empty');
        }
      } else {
        logNamedInfo(info: 'FCM token ready');
        return true;
      }
    } catch (e) {
      if (lastTry) {
        logNamedError(error: 'token exception: $e');
      } else {
        logNamedInfo(info: 'token exception: $e');
      }
    }
    return false;
  }

  ///
  Future<AuthorizationStatus> requestPermission() async {
    if (_messaging == null) {
      logNamedError(
        error:
            'FCM instance is null. '
            'Did you forget to call FirebaseMessagingService->prepare?',
      );
      return AuthorizationStatus.notDetermined;
    }

    final NotificationSettings settings = await _messaging!.requestPermission();
    logNamedInfo(
      info: 'User granted permission: ${settings.authorizationStatus}',
    );
    return settings.authorizationStatus;
  }

  /// User pressed on push and application opened from Terminated state
  Future<void> _onInitializationHandle() async {
    final RemoteMessage? message = await _messaging!.getInitialMessage();
    if (message == null) return;

    /// Create data from message
    final pushEntity = PushEntity.fromMessage(message);

    logNamedInfo(info: 'Got push "${pushEntity.title}" in Terminated state');

    _handleMessage(pushEntity);
  }

  /// User pressed on push and application opened
  /// from Background state on Android or
  /// from Background or Foreground state on iOS
  void _onOpenedListen(RemoteMessage message) {
    /// Create data from message
    final pushEntity = PushEntity.fromMessage(message);

    logNamedInfo(info: 'Got push "${pushEntity.title}" in Background state');

    _handleMessage(pushEntity);
  }

  /// User pressed on push and application opened from Foreground state
  ///
  /// Used only for Android
  void _onForegroundListen(RemoteMessage message) {
    /// Create data from message
    final pushEntity = PushEntity.fromMessage(message);

    logNamedInfo(info: 'Got push "${pushEntity.title}" in Foreground state');

    ///
    getIt<LocalNotificationsService>().show(
      pushEntity: pushEntity,
      picture: message.notification?.android?.imageUrl,
    );
  }

  /// User pressed on push and application opened from Foreground state
  void _handleForegroundMessage(String? payload) {
    logNamedInfo(info: 'Handle push in Foreground state');

    if (payload?.isEmpty ?? true) {
      logNamedInfo(info: 'Foreground push without payload');
      return;
    }

    try {
      /// Create data from payload
      final pushEntity = PushEntity.fromString(payload!);

      /// And handle it as a common push message
      _handleMessage(pushEntity);
    } catch (e) {
      logNamedError(
        error:
            'Foreground push with wrong payload: $payload\n'
            'Got error $e',
      );
    }
  }

  ///
  void _handleMessage(PushEntity pushEntity) {
    logNamedInfo(info: 'Handle push');

    /// Check push's `data` field and try to get useful information from there
    final Map<String, dynamic>? payload = pushEntity.data;

    if (payload?.isEmpty ?? true) {
      /// There is nothing to get
      logNamedInfo(info: 'Push without payload');
      return;
    }

    pushSubject.add(payload!);
  }

  /// Token changed listener
  // It can not be a setter because it's using as callback
  // ignore: use_setters_to_change_properties
  void _tokenChanged(String newToken) {
    _token = newToken;
    onTokenChanged?.call(_token);
  }
}
