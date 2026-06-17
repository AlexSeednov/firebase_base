import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_base/core/entity/push_entity.dart';

///
typedef HandleMessage = void Function(String? message);

/// Singleton
///
/// Used only for Android
final class LocalNotificationsService {
  ///
  static const _payloadField = 'payload';

  /// Channel for getting local notifications on Android
  late NotificationChannel _androidLocalChannel;

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

    /// Prepare settings
    _androidLocalChannel = NotificationChannel(
      channelGroupKey: '$key-group',
      channelKey: key,
      channelName: '$name Push Notification',
      channelDescription: 'Notification channel for informing user',
      importance: NotificationImportance.Max,
    );

    await _instance.initialize(
      // Monochrome small icon; null falls back to the default application icon
      icon,
      [_androidLocalChannel],
    );

    await _instance.setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );
  }

  /// Show local message
  Future<bool> show({required PushEntity pushEntity, String? picture}) =>
      _instance.createNotification(
        content: NotificationContent(
          id: pushEntity.hashCode,
          channelKey: _androidLocalChannel.channelKey!,
          title: pushEntity.title,
          body: pushEntity.body,
          payload: {_payloadField: pushEntity.toString()},
          largeIcon: picture,
        ),
      );

  /// Use this method to detect when the user taps on a notification
  /// or action button
  ///
  /// Must be a static
  ///
  /// Need to use @pragma("vm:entry-point") in each static method to identify
  /// to the Flutter engine that the dart address will be called from native
  /// and should be preserved
  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
    ReceivedAction data,
  ) async =>
      _handleMessage?.call(data.payload?[_payloadField]);
}
