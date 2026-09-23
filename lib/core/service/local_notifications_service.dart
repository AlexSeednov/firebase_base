import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_base/core/entity/push_entity.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

/// Receives the payload of a tapped notification.
typedef HandleMessage = void Function(String? message);

/// Local notifications for the pushes that arrive in the foreground on
/// Android, where the OS does not show them.
@lazySingleton
final class LocalNotificationsService {
  ///
  @visibleForTesting
  LocalNotificationsService();

  ///
  static const String _logName = 'Local notifications';

  /// Payload key of the serialized [PushEntity].
  static const _payloadField = 'payload';

  /// Keeps a generated notification id inside the signed 32-bit range
  /// Android accepts.
  static const int _idMask = 0x7FFFFFFF;

  /// Id of the channel for getting local notifications on Android.
  ///
  /// Kept instead of the whole channel object: after [prepare] nothing else of
  /// it is needed, and an empty value is a readable "not prepared yet" state.
  String _channelKey = '';

  ///
  final _instance = AwesomeNotifications();

  /// Static, like [_onActionReceivedMethod] that calls it.
  static HandleMessage? _handleMessage;

  /// **name** — application name: the channel group, and the channel name
  /// the user sees in the system notification settings.
  ///
  /// **channelKey** — channel id. Must equal
  /// `com.google.firebase.messaging.default_notification_channel_id` in the
  /// application's `AndroidManifest.xml`: FCM shows background and terminated
  /// pushes on that channel, this service shows foreground ones on it. On a
  /// mismatch FCM falls back to a default-importance channel, which shows no
  /// heads-up banner. Keep it the same for every flavor: channels are per
  /// application anyway. `null` falls back to `'$name-notifications'`.
  ///
  /// **icon** — status bar icon, e.g.
  /// `'resource://drawable/ic_stat_notification'`. Must be monochrome (white
  /// on transparent), otherwise Android renders it as a white blob. `null`
  /// falls back to the launcher icon.
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

    /// The group is registered together with the channel: Android resolves
    /// [NotificationChannel.channelGroupKey] against the groups passed to
    /// [AwesomeNotifications.initialize]. A missing group costs an error log
    /// with a stack trace on every launch and leaves the channel ungrouped in
    /// the system settings; the pushes still work.
    final String groupKey = '$key-group';

    final androidLocalChannel = NotificationChannel(
      channelGroupKey: groupKey,
      channelKey: key,
      channelName: '$name Push Notification',
      channelDescription: 'Notification channel for informing user',
      importance: NotificationImportance.Max,
    );

    /// Groups the channel under the application name in the system settings
    final androidLocalChannelGroup = NotificationChannelGroup(
      channelGroupKey: groupKey,
      channelGroupName: name,
    );

    await _instance.initialize(
      // The default status bar icon; null means the launcher icon
      icon,
      [androidLocalChannel],
      channelGroups: [androidLocalChannelGroup],
    );

    await _instance.setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );
  }

  /// Returns whether the notification was created; `false` before [prepare].
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

  /// Derived from the message, not the object: FCM delivers at least once,
  /// and Android replaces a notification that reuses a shown id, so a
  /// redelivered push updates its banner instead of stacking a duplicate.
  ///
  /// Must fit a signed 32-bit integer: a string's `hashCode` does, the
  /// timestamp fallback for a message without an id is masked down to it.
  int _notificationId(PushEntity pushEntity) =>
      pushEntity.messageId?.hashCode ??
      DateTime.now().millisecondsSinceEpoch & _idMask;

  /// Drops the static [_handleMessage]: it outlives this instance, and after a
  /// container reset it would still call into the disposed messaging service.
  @disposeMethod
  void dispose() {
    _handleMessage = null;
  }

  /// A tap on a notification or on its action button.
  ///
  /// Called from native code, possibly on a cold start: the plugin requires a
  /// static method, and `vm:entry-point` keeps the compiler from dropping it.
  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(ReceivedAction data) async =>
      _handleMessage?.call(data.payload?[_payloadField]);
}
