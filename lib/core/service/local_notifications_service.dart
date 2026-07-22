import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_base/core/entity/push_entity.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

///
typedef HandleMessage = void Function(String? message);

/// Used only for Android
@lazySingleton
final class LocalNotificationsService {
  ///
  @visibleForTesting
  LocalNotificationsService();

  /// Name for logging
  static const String _logName = 'Local notifications';

  ///
  static const _payloadField = 'payload';

  /// Keeps a generated notification id inside the signed 32-bit range Android
  /// accepts
  static const int _idMask = 0x7FFFFFFF;

  /// Id of the channel for getting local notifications on Android.
  ///
  /// Kept instead of the whole channel object: after [prepare] nothing else of
  /// it is needed, and an empty value is a readable "not prepared yet" state.
  String _channelKey = '';

  /// Local notifications instance
  final _instance = AwesomeNotifications();

  ///
  static HandleMessage? _handleMessage;

  /// **name** - Android application name for system notification settings
  /// (used as the user-visible channel name)
  ///
  /// **channelKey** - stable id of the notification channel. It MUST exactly
  /// match `com.google.firebase.messaging.default_notification_channel_id` in
  /// the app's `AndroidManifest.xml`: in Background/Terminated state FCM shows
  /// the push itself on that channel, while in Foreground the same channel is
  /// used here. If they differ, FCM falls back to a default-importance channel
  /// and the heads-up banner is not shown. Keep it flavor-independent (channels
  /// are per-app). `null` falls back to the legacy `'$name-notifications'` key.
  ///
  /// **icon** - small (status bar) icon resource for foreground notifications,
  /// e.g. `'resource://drawable/ic_stat_notification'`. Must be a monochrome
  /// (transparent + white) asset, otherwise Android renders the launcher icon
  /// as a white blob. `null` falls back to the application launcher icon.
  Future<void> prepare({
    required HandleMessage handleMessage,
    required String name,
    String? channelKey,
    String? icon,
  }) async {
    _handleMessage = handleMessage;

    /// Channel id is shared with FCM via the manifest, see [channelKey]
    final String key = channelKey ?? '$name-notifications';
    _channelKey = key;

    /// Prepare settings
    final androidLocalChannel = NotificationChannel(
      channelGroupKey: '$key-group',
      channelKey: key,
      channelName: '$name Push Notification',
      channelDescription: 'Notification channel for informing user',
      importance: NotificationImportance.Max,
    );

    await _instance.initialize(
      // Monochrome small icon; null falls back to the default application icon
      icon,
      [androidLocalChannel],
    );

    await _instance.setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );
  }

  /// Show local message
  Future<bool> show({required PushEntity pushEntity, String? picture}) async {
    if (_channelKey.isEmpty) {
      logError(error: '$_logName: show is called before prepare');
      return false;
    }

    return _instance.createNotification(
      content: NotificationContent(
        id: _notificationId(pushEntity),
        channelKey: _channelKey,
        title: pushEntity.title,
        body: pushEntity.body,
        payload: {_payloadField: pushEntity.toString()},
        largeIcon: picture,
      ),
    );
  }

  /// Android replaces a notification that carries an already shown id, so the
  /// id has to be derived from the message rather than from the object: FCM
  /// delivers at-least-once, and a redelivered push must update its banner
  /// instead of stacking a duplicate next to it.
  ///
  /// The id must fit into a signed 32-bit integer - `hashCode` does, while the
  /// timestamp fallback for a message without an id is masked down to it.
  int _notificationId(PushEntity pushEntity) =>
      pushEntity.messageId?.hashCode ??
      DateTime.now().millisecondsSinceEpoch & _idMask;

  /// Releases the callback into the previous messaging service.
  ///
  /// [_handleMessage] has to be static (see [_onActionReceivedMethod]), so it
  /// is not bound to this instance's lifetime and survives a container reset
  /// on its own.
  @disposeMethod
  void dispose() {
    _handleMessage = null;
  }

  /// Use this method to detect when the user taps on a notification
  /// or action button
  ///
  /// Must be a static
  ///
  /// Need to use @pragma("vm:entry-point") in each static method to identify
  /// to the Flutter engine that the dart address will be called from native
  /// and should be preserved
  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(ReceivedAction data) async =>
      _handleMessage?.call(data.payload?[_payloadField]);
}
