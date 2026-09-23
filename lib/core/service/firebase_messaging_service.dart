import 'dart:async';

import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:firebase_base/core/entity/push_entity.dart';
import 'package:firebase_base/core/service/local_notifications_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

/// Firebase Cloud Messaging: the device token, the notification permission
/// and the pushes the user opens, whose payloads go out through
/// [pushSubject].
///
/// Who shows a push depends on the application state:
///
/// * **Background** (running but not in view) and **Terminated** (not running,
///   or the device is locked) — the OS itself.
/// * **Foreground** (in view) — nobody by default. iOS shows it once told to
///   through the presentation options. Android is not reliable even with a
///   high-importance channel, so the push is shown as a local notification.
///
/// Details in the [Firebase docs](https://firebase.google.com/docs/cloud-messaging/flutter/receive)
/// and on [a diagram](https://user-images.githubusercontent.com/40064496/197368144-7bfcee7e-644a-4bdc-80f1-b4d38c2eaaff.png).
@lazySingleton
final class FirebaseMessagingService with LoggingMixin {
  ///
  @visibleForTesting
  FirebaseMessagingService();

  ///
  @override
  final String logName = 'Firebase messaging';

  ///
  String _token = '';

  /// FCM registration token of the device; empty until [prepare] gets one.
  /// A later refresh is announced through [onTokenChanged].
  String get token => _token;

  ///
  String? _apnsToken;

  /// APNs token: iOS only, `null` until the OS issues one.
  String? get apnsToken => _apnsToken;

  /// `null` until [prepare] and after [dispose].
  FirebaseMessaging? _messaging;

  /// Messaging instance for the paths that are only reachable after a
  /// successful [prepare] — a missing instance there is a programming error,
  /// not a runtime condition to branch on.
  FirebaseMessaging get _requireMessaging {
    final FirebaseMessaging? messaging = _messaging;
    if (messaging == null) {
      throw StateError(
        'FCM instance is null. '
        'Did you forget to call FirebaseMessagingService->prepare?',
      );
    }
    return messaging;
  }

  /// Guards against a second [prepare]: the stream listeners below are not
  /// idempotent, a repeated call would stack a second set on top of the first
  /// and every push would be handled twice.
  bool _isPrepared = false;

  /// Foreground messages listener - Android only, see [prepare]
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  ///
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Listener of the pushes that opened the application
  StreamSubscription<RemoteMessage>? _openedSubscription;

  /// Payloads (`data`) of the pushes the user opened.
  ///
  /// A [BehaviorSubject], so the push that launched the application reaches
  /// a listener that subscribes after [prepare]. The flip side: every new
  /// listener gets the latest payload again.
  final pushSubject = BehaviorSubject<Map<String, dynamic>>();

  /// Called with the new token when FCM refreshes it. The token [prepare]
  /// gets is not announced: read it from [token].
  void Function(String)? onTokenChanged;

  /// Returns whether messaging is ready. Never throws; a repeated call is a
  /// no-op.
  ///
  /// **name**, **channelKey**, **icon** — the Android notification channel
  /// and its status bar icon, see [LocalNotificationsService.prepare].
  Future<bool> prepare({
    required String name,
    String? channelKey,
    String? icon,
  }) async {
    // Future(AlexSeednov): FCM on web needs a `firebase-messaging-sw.js`
    // service worker in the application and a VAPID key passed to `getToken`;
    // wire both here when web pushes are needed.
    if (isWeb) {
      logNamedInfo(info: 'is not supported on web yet, skipped');
      return false;
    }

    if (_isPrepared) {
      logNamedInfo(info: 'already initialized');
      return true;
    }

    try {
      _messaging = FirebaseMessaging.instance;

      if (isIOS) {
        /// Without these options iOS does not show a push in the foreground
        await _requireMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (isAndroid) {
        /// Android never shows a push in the foreground: it arrives in
        /// [FirebaseMessaging.onMessage] and is shown as a local notification
        await getIt<LocalNotificationsService>().prepare(
          handleMessage: _handleForegroundMessage,
          name: name,
          channelKey: channelKey,
          icon: icon,
        );
        _foregroundSubscription = FirebaseMessaging.onMessage.listen(
          _onForegroundListen,
        );
      }

      final bool result = await _getToken(lastTry: false);
      if (!result) {
        /// Right after start-up the token is often not ready yet — on iOS the
        /// APNs token arrives later — so one more try after a second
        logNamedInfo(info: 'Try to get tokens one more time');
        await Future<void>.delayed(const Duration(seconds: 1));
        await _getToken(lastTry: true);
      }

      _tokenRefreshSubscription = _requireMessaging.onTokenRefresh.listen(
        _tokenChanged,
      );

      unawaited(_onInitializationHandle());
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _onOpenedListen,
      );
    } catch (e) {
      logNamedError(error: 'initialization exception: $e');
      return false;
    }

    _isPrepared = true;
    logNamedInfo(info: 'initialized');
    return true;
  }

  /// `@disposeMethod`, or a container reset leaves the listeners running
  /// into the next container.
  @disposeMethod
  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _openedSubscription?.cancel();
    _foregroundSubscription = null;
    _tokenRefreshSubscription = null;
    _openedSubscription = null;

    await pushSubject.close();

    _messaging = null;
    _isPrepared = false;
  }

  /// Returns whether the FCM token arrived. A failure is logged as an error
  /// on the [lastTry] only, as an info before it.
  Future<bool> _getToken({required bool lastTry}) async {
    try {
      if (isIOS) {
        _apnsToken = await _requireMessaging.getAPNSToken();
        if (_apnsToken == null) {
          /// Not an error by itself: [FirebaseMessaging.getToken] then fails,
          /// and that failure is logged below
          logNamedInfo(info: 'apnsToken is null');
        } else {
          logNamedInfo(info: 'apnsToken ready');
        }
      }

      _token = await _requireMessaging.getToken() ?? '';
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

  /// Asks the user to allow notifications and returns the outcome.
  ///
  /// Called from the application flow, often unawaited, so nothing here
  /// throws: messaging that is not prepared yet — a legitimate state there —
  /// and a failed request are both logged and answered with
  /// [AuthorizationStatus.notDetermined].
  Future<AuthorizationStatus> requestPermission() async {
    /// Messaging is never prepared on the web, see [prepare]: expected there,
    /// hence an info instead of the error below
    if (isWeb) {
      logNamedInfo(info: 'permission request skipped on web');
      return AuthorizationStatus.notDetermined;
    }

    final FirebaseMessaging? messaging = _messaging;
    if (messaging == null) {
      logNamedError(
        error:
            'FCM instance is null. '
            'Did you forget to call FirebaseMessagingService->prepare?',
      );
      return AuthorizationStatus.notDetermined;
    }

    try {
      final NotificationSettings settings = await messaging.requestPermission();
      logNamedInfo(
        info: 'User granted permission: ${settings.authorizationStatus}',
      );
      return settings.authorizationStatus;
    } catch (e) {
      logNamedError(error: 'permission request exception: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// The push the user tapped to launch the application from the terminated
  /// state.
  ///
  /// Runs unawaited, so a failure is logged here: escaping as an unhandled
  /// error, it would reach the crash reporter and be counted as a crash.
  Future<void> _onInitializationHandle() async {
    final RemoteMessage? message;
    try {
      message = await _requireMessaging.getInitialMessage();
    } catch (e) {
      logNamedError(error: 'initial message exception: $e');
      return;
    }
    if (message == null) return;

    final pushEntity = PushEntity.fromMessage(message);

    logNamedInfo(info: 'Got push "${pushEntity.title}" in Terminated state');

    _handleMessage(pushEntity);
  }

  /// The user tapped a push while the application was running: in the
  /// background on Android, in the background or foreground on iOS.
  void _onOpenedListen(RemoteMessage message) {
    final pushEntity = PushEntity.fromMessage(message);

    logNamedInfo(info: 'Got push "${pushEntity.title}" in Background state');

    _handleMessage(pushEntity);
  }

  /// A push arrived in the foreground on Android, where the OS does not show
  /// it: it is shown as a local notification.
  void _onForegroundListen(RemoteMessage message) {
    final pushEntity = PushEntity.fromMessage(message);

    logNamedInfo(info: 'Got push "${pushEntity.title}" in Foreground state');

    unawaited(
      _showForegroundNotification(
        pushEntity: pushEntity,
        picture: message.notification?.android?.imageUrl,
      ),
    );
  }

  /// Nothing waits for the banner, but the failure must not escape as an
  /// unhandled asynchronous error: it would reach the crash reporter and get
  /// counted as a crash, while an unreachable [picture] only costs the push
  /// its illustration.
  Future<void> _showForegroundNotification({
    required PushEntity pushEntity,
    String? picture,
  }) async {
    try {
      final bool isShown = await getIt<LocalNotificationsService>().show(
        pushEntity: pushEntity,
        picture: picture,
      );
      if (!isShown) {
        logNamedError(error: 'Foreground notification was not shown');
      }
    } catch (e) {
      logNamedError(error: 'Foreground notification exception: $e');
    }
  }

  /// The user tapped a local notification shown by [_onForegroundListen];
  /// [payload] is the [PushEntity] it carries.
  void _handleForegroundMessage(String? payload) {
    logNamedInfo(info: 'Handle push in Foreground state');

    if (payload?.isEmpty ?? true) {
      logNamedInfo(info: 'Foreground push without payload');
      return;
    }

    try {
      final pushEntity = PushEntity.fromString(payload!);

      _handleMessage(pushEntity);
    } catch (e) {
      logNamedError(
        error:
            'Foreground push with wrong payload: $payload\n'
            'Got error $e',
      );
    }
  }

  /// A push without a `data` payload is dropped: there is nothing to route
  /// by.
  void _handleMessage(PushEntity pushEntity) {
    logNamedInfo(info: 'Handle push');

    /// The Android foreground path arrives through a static callback in
    /// [LocalNotificationsService], which can outlive this instance - adding
    /// to an already closed subject would throw.
    if (pushSubject.isClosed) {
      logNamedInfo(info: 'Push after dispose, ignored');
      return;
    }

    final Map<String, dynamic>? payload = pushEntity.data;

    if (payload?.isEmpty ?? true) {
      logNamedInfo(info: 'Push without payload');
      return;
    }

    pushSubject.add(payload!);
  }

  /// A method, not a setter: a setter cannot be torn off as a listener.
  void _tokenChanged(String newToken) {
    _token = newToken;
    onTokenChanged?.call(_token);
  }
}
